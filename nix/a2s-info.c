/* lembitu-a2s: one bounded Steam A2S_INFO query.
 *
 *   lembitu-a2s [host] [port]        defaults 127.0.0.1 2457 (the query port)
 *
 * Exit 0 and one line "A2S ready: <name> players=<n>/<max>" when the server answers with a
 * well-formed A2S_INFO reply; exit 1 otherwise. The server answers it only with -public 1; under
 * -public 0 its query port sends nothing, so neither the readiness check nor the monitor uses it
 * (lembitu-sns-probe is theirs). The exchange: the request, the challenge the server may answer
 * first (0x41 and four bytes, resent appended to the request), then the 0x49 reply, validated
 * through its player counts. Each receive waits at most 3 s.
 */
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

static const unsigned char request[] = "\xff\xff\xff\xffTSource Engine Query";  /* NUL included */

static int fail(const char *why) {
  fprintf(stderr, "A2S query failed: %s\n", why);
  return 1;
}

/* The end of the NUL-terminated string starting at pos, or -1 when it runs off the reply. */
static ssize_t skip_string(const unsigned char *reply, ssize_t length, ssize_t pos) {
  while (pos < length && reply[pos] != 0) pos++;
  return pos < length ? pos + 1 : -1;
}

int main(int argc, char **argv) {
  const char *host = argc > 1 ? argv[1] : "127.0.0.1";
  int port = argc > 2 ? atoi(argv[2]) : 2457;
  if (argc > 3 || port <= 0 || port > 65535) return fail("usage: lembitu-a2s [host] [port]");

  struct sockaddr_in server = { .sin_family = AF_INET, .sin_port = htons((unsigned short)port) };
  if (inet_pton(AF_INET, host, &server.sin_addr) != 1) return fail("host must be an IPv4 address");

  int sock = socket(AF_INET, SOCK_DGRAM, 0);
  if (sock < 0) return fail("socket");
  struct timeval timeout = { .tv_sec = 3 };
  setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof timeout);
  if (connect(sock, (struct sockaddr *)&server, sizeof server) < 0) return fail("connect");

  unsigned char packet[sizeof request + 4];
  memcpy(packet, request, sizeof request);
  size_t packet_length = sizeof request;
  unsigned char reply[1400];
  ssize_t length = 0;
  for (int attempt = 0; attempt < 2; attempt++) {
    if (send(sock, packet, packet_length, 0) < 0) return fail("send");
    length = recv(sock, reply, sizeof reply, 0);
    if (length < 5) return fail("no reply");
    if (memcmp(reply, "\xff\xff\xff\xff", 4) != 0) return fail("not a Steam reply");
    if (reply[4] == 'A' && length == 9 && attempt == 0) {
      memcpy(packet + sizeof request, reply + 5, 4);  /* the challenge, resent once */
      packet_length = sizeof request + 4;
      continue;
    }
    break;
  }
  close(sock);
  if (reply[4] != 'I') return fail("not an A2S_INFO reply");

  /* Header, protocol, then name, map, folder and game: four strings. */
  ssize_t pos = 6, name_at = 6;
  for (int field = 0; field < 4; field++) {
    pos = skip_string(reply, length, pos);
    if (pos < 0) return fail("truncated reply");
  }
  if (pos + 5 > length) return fail("truncated reply");
  unsigned players = reply[pos + 2], maximum = reply[pos + 3], bots = reply[pos + 4];
  if (maximum == 0 || players > maximum || bots > maximum) return fail("invalid player counts");
  printf("A2S ready: %s players=%u/%u\n", (const char *)reply + name_at, players, maximum);
  return 0;
}
