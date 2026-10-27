/* lembitu-logmark: pass the server's stdout through unchanged, and create a marker file the first
 * time a line contains a given text.
 *
 *   lembitu-logmark <marker-file> [text]      text defaults to "Opened Steam server"
 *
 * The readiness check (lembitu-ready) needs to know the Unity log said "Opened Steam server": the
 * world is loaded and the game's listen socket is open (docs/build.md, native testing: "Game
 * server connected" is only the Steam registration, before both). That line goes to stdout only,
 * so the entrypoint points the server's stdout at this filter and the container log still gets
 * every byte, in order, as it arrives.
 *
 * It must never be the reason the server stops. A dead filter would break the server's stdout pipe,
 * and the server would die of SIGPIPE on its next log line, perhaps mid-save. So it ignores SIGINT,
 * SIGTERM and SIGHUP (the entrypoint's PID 1 forwards the stop signal to the whole process group,
 * this filter included), and it exits only at end of input, when the server has closed its stdout.
 * Reads and writes are unbuffered, so nothing is held back when the container stops.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int write_all(const char *data, size_t length) {
  while (length > 0) {
    ssize_t written = write(STDOUT_FILENO, data, length);
    if (written < 0) {
      if (errno == EINTR) continue;
      return -1;
    }
    data += written;
    length -= (size_t)written;
  }
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3) {
    fprintf(stderr, "usage: lembitu-logmark <marker-file> [text]\n");
    return 2;
  }
  const char *marker = argv[1];
  const char *text = argc > 2 ? argv[2] : "Opened Steam server";
  size_t text_length = strlen(text);
  if (text_length == 0 || text_length > 1024) {
    fprintf(stderr, "lembitu-logmark: the text must be 1 to 1024 bytes\n");
    return 2;
  }

  signal(SIGINT, SIG_IGN);
  signal(SIGTERM, SIG_IGN);
  signal(SIGHUP, SIG_IGN);
  /* A closed container log must not kill the filter: write() then fails with EPIPE, output_ok drops,
   * and the server's stdout keeps draining, so the server never sees SIGPIPE either. */
  signal(SIGPIPE, SIG_IGN);

  /* The last text_length - 1 bytes of the previous read, so a match split across reads counts. */
  char window[1024 + 65536];
  size_t carried = 0;
  int marked = 0, output_ok = 1;
  for (;;) {
    ssize_t got = read(STDIN_FILENO, window + carried, 65536);
    if (got < 0) {
      if (errno == EINTR) continue;
      return 1;
    }
    if (got == 0) return 0;
    /* A lost container log must not stop the server: keep draining, stop writing. */
    if (output_ok && write_all(window + carried, (size_t)got) < 0) output_ok = 0;
    size_t filled = carried + (size_t)got;
    if (!marked && memmem(window, filled, text, text_length) != NULL) {
      int fd = open(marker, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
      if (fd >= 0) {
        close(fd);
        marked = 1;
      }
    }
    carried = text_length - 1 < filled ? text_length - 1 : filled;
    memmove(window, window + filled - carried, carried);
  }
}
