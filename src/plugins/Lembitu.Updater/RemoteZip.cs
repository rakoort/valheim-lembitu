using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;

namespace Lembitu.Updater;

/// <summary>Reads single files out of a zip that lives on a web server, from byte ranges: the end
/// record, the central directory, then only the entries an update needs. Plain zip as Info-ZIP's
/// zip(1) writes it for the Pack; zip64 and anything but stored or deflated entries are refused.</summary>
internal static class RemoteZip
{
    internal sealed class Entry
    {
        internal string Name = "";
        internal int Method;
        internal long CompressedSize, Size, LocalOffset;
        internal int NameLength;
    }

    internal const int EndRecordSearch = 22 + 65535;

    /// <summary>The central directory's (offset, size) from the archive's last bytes.</summary>
    internal static (long Offset, long Size) FindCentralDirectory(byte[] tail)
    {
        for (int i = tail.Length - 22; i >= 0; i--)
        {
            if (U32(tail, i) != 0x06054b50) continue;
            long size = U32(tail, i + 12), offset = U32(tail, i + 16);
            if (size == 0xFFFFFFFF || offset == 0xFFFFFFFF || U16(tail, i + 10) == 0xFFFF)
                throw new InvalidDataException("the Pack zip is zip64, which the updater does not read");
            return (offset, size);
        }
        throw new InvalidDataException("no zip end record in the Pack's last bytes");
    }

    internal static Dictionary<string, Entry> ReadCentralDirectory(byte[] directory)
    {
        var entries = new Dictionary<string, Entry>(StringComparer.Ordinal);
        int at = 0;
        while (at + 46 <= directory.Length && U32(directory, at) == 0x02014b50)
        {
            int nameLength = U16(directory, at + 28), extra = U16(directory, at + 30), comment = U16(directory, at + 32);
            var entry = new Entry
            {
                Method = U16(directory, at + 10),
                CompressedSize = U32(directory, at + 20),
                Size = U32(directory, at + 24),
                NameLength = nameLength,
                LocalOffset = U32(directory, at + 42),
                Name = System.Text.Encoding.UTF8.GetString(directory, at + 46, nameLength)
            };
            if (entry.CompressedSize == 0xFFFFFFFF || entry.Size == 0xFFFFFFFF || entry.LocalOffset == 0xFFFFFFFF)
                throw new InvalidDataException("zip64 entry in the Pack zip: " + entry.Name);
            entries[entry.Name] = entry;
            at += 46 + nameLength + extra + comment;
        }
        if (entries.Count == 0) throw new InvalidDataException("the Pack zip's central directory is empty");
        return entries;
    }

    /// <summary>The bytes to fetch for an entry: its local header, name, a generous allowance for
    /// the local extra field (which may differ from the central one) and its data.</summary>
    internal static long SpanEstimate(Entry entry) => 30 + entry.NameLength + 1024 + entry.CompressedSize;

    /// <summary>Unpacks one entry from a buffer holding its local header at <paramref name="at"/>.
    /// Returns null when the buffer ends before the entry's data does.</summary>
    internal static byte[]? Extract(byte[] buffer, int at, Entry entry)
    {
        if (at + 30 > buffer.Length) return null;
        if (U32(buffer, at) != 0x04034b50) throw new InvalidDataException("no local header for " + entry.Name);
        long start = at + 30 + U16(buffer, at + 26) + U16(buffer, at + 28);
        if (start + entry.CompressedSize > buffer.Length) return null;
        if (entry.Method == 0)
        {
            var stored = new byte[entry.Size];
            Buffer.BlockCopy(buffer, (int)start, stored, 0, (int)entry.Size);
            return stored;
        }
        if (entry.Method != 8) throw new InvalidDataException($"{entry.Name} uses zip method {entry.Method}");
        var output = new byte[entry.Size];
        using var inflate = new DeflateStream(new MemoryStream(buffer, (int)start, (int)entry.CompressedSize), CompressionMode.Decompress);
        int read = 0;
        while (read < output.Length)
        {
            int n = inflate.Read(output, read, output.Length - read);
            if (n == 0) throw new InvalidDataException(entry.Name + " ends early");
            read += n;
        }
        return output;
    }

    private static uint U32(byte[] b, int i) => (uint)(b[i] | b[i + 1] << 8 | b[i + 2] << 16 | b[i + 3] << 24);
    private static int U16(byte[] b, int i) => b[i] | b[i + 1] << 8;
}
