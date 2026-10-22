import java.io.*;
import java.nio.*;
import java.nio.channels.FileChannel;
import java.nio.file.*;

/**
 * The names of the recordings in an FMOD Studio bank (its FSB5 part), one per line
 * as "index<TAB>name" (index from 1, as vgmstream-cli -s counts). Every FSB5 in the
 * bank is listed, indices running on.
 *
 *   java BankNames.java <file.bank> <out.txt>
 */
public class BankNames {
    public static void main(String[] args) throws Exception {
        try (FileChannel ch = FileChannel.open(Paths.get(args[0]), StandardOpenOption.READ);
             PrintWriter out = new PrintWriter(new OutputStreamWriter(new FileOutputStream(args[1]), "UTF-8"))) {
            long size = ch.size();
            int index = 0;
            long pos = 0;
            ByteBuffer win = ByteBuffer.allocate(1 << 20);
            while (pos < size) {
                long at = find(ch, pos, size);
                if (at < 0) break;
                ByteBuffer h = ByteBuffer.allocate(60).order(ByteOrder.LITTLE_ENDIAN);
                ch.read(h, at);
                h.flip();
                h.position(4);
                int version = h.getInt(), num = h.getInt(), shdr = h.getInt(), names = h.getInt();
                int headerSize = version == 0 ? 0x40 : 0x3C;
                ByteBuffer nt = ByteBuffer.allocate(names).order(ByteOrder.LITTLE_ENDIAN);
                ch.read(nt, at + headerSize + shdr);
                nt.flip();
                for (int i = 0; i < num; i++) {
                    int off = nt.getInt(i * 4);
                    StringBuilder sb = new StringBuilder();
                    for (int k = off; k < names && nt.get(k) != 0; k++) sb.append((char) nt.get(k));
                    index++;
                    out.println(index + "\t" + sb);
                }
                pos = at + 4;
            }
            System.out.println("names: " + index);
        }
    }

    /** The next "FSB5" from `from`. */
    static long find(FileChannel ch, long from, long size) throws IOException {
        ByteBuffer b = ByteBuffer.allocate(1 << 20);
        for (long p = from; p < size; p += b.capacity() - 3) {
            b.clear();
            int n = ch.read(b, p);
            if (n <= 0) return -1;
            for (int i = 0; i + 3 < n; i++)
                if (b.get(i) == 'F' && b.get(i + 1) == 'S' && b.get(i + 2) == 'B' && b.get(i + 3) == '5') return p + i;
        }
        return -1;
    }
}
