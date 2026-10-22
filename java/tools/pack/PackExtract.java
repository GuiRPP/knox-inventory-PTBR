import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.regex.Pattern;
import javax.imageio.ImageIO;

/**
 * Pictures out of the game's texture packs (media/texturepacks/*.pack): item
 * icons (Item_*), container icons (Container_*) and the rest, as the game itself
 * has them - for pictures of the mod (news, Workshop page), not shipped in it.
 *
 * A pack (zombie.core.textures.TexturePackPage.loadFromPackFile): optionally
 * "PZPK" + version, then the number of pages; a page is its name, the number of
 * its pictures, a mask flag, for each picture its name and x, y, w, h, offset
 * x, y, full w, h (ints, little endian), then the page's image as a PNG, then
 * the end mark 0xDEADBEEF. A picture is written at its full size with its
 * offset, as the game draws it.
 *
 *   java PackExtract.java <file.pack> <outDir> <name regex> [list]
 */
public class PackExtract {
    static ByteBuffer bb;

    static int i32() { return bb.getInt(); }

    static String str() {
        int n = i32();
        byte[] b = new byte[n];
        bb.get(b);
        return new String(b, java.nio.charset.StandardCharsets.ISO_8859_1);
    }

    record Entry(String name, int x, int y, int w, int h, int ox, int oy, int fw, int fh) {}

    public static void main(String[] args) throws Exception {
        byte[] data = Files.readAllBytes(new File(args[0]).toPath());
        File out = new File(args[1]);
        Pattern want = Pattern.compile(args[2]);
        boolean list = args.length > 3 && args[3].equals("list");
        out.mkdirs();
        bb = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN);
        boolean pzpk = data[0] == 'P' && data[1] == 'Z' && data[2] == 'P' && data[3] == 'K';
        if (pzpk) {
            bb.position(4);
            i32();   // version
        }
        int pages = i32();
        int written = 0;
        for (int p = 0; p < pages && bb.remaining() > 8; p++) {
            String page = str();
            int n = i32();
            i32();   // mask
            if (args.length > 3 && args[3].equals("pages")) System.err.println("page " + p + " " + page + " " + n + " at " + bb.position());
            ArrayList<Entry> entries = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                String name = str();
                entries.add(new Entry(name, i32(), i32(), i32(), i32(), i32(), i32(), i32(), i32()));
            }
            // the page's PNG. "PZPK" packs give its length before it and go on with the
            // next page right after it; the older ones end a page with 0xDEADBEEF
            int start = bb.position();
            int pngLen = pzpk ? i32() : -1;
            if (pzpk) start = bb.position();
            while (!(data[start] == (byte) 0x89 && data[start + 1] == 'P' && data[start + 2] == 'N' && data[start + 3] == 'G')) start++;
            int pos = start + 8;
            if (pzpk) pos = start + pngLen;
            else while (true) {
                int len = ByteBuffer.wrap(data, pos, 4).order(ByteOrder.BIG_ENDIAN).getInt();
                String type = new String(data, pos + 4, 4, java.nio.charset.StandardCharsets.ISO_8859_1);
                pos += 12 + len;
                if (type.equals("IEND")) break;
            }
            boolean any = false;
            for (Entry e : entries) if (want.matcher(e.name).find()) any = true;
            if (any) {
                BufferedImage img = ImageIO.read(new ByteArrayInputStream(data, start, pos - start));
                for (Entry e : entries) {
                    if (!want.matcher(e.name).find()) continue;
                    if (list) { System.out.println(page + "  " + e.name + "  " + e.fw + "x" + e.fh); continue; }
                    BufferedImage full = new BufferedImage(Math.max(1, e.fw), Math.max(1, e.fh), BufferedImage.TYPE_INT_ARGB);
                    full.getGraphics().drawImage(img.getSubimage(e.x, e.y, e.w, e.h), e.ox, e.oy, null);
                    ImageIO.write(full, "png", new File(out, e.name + ".png"));
                    written++;
                }
            }
            if (pzpk) { bb.position(pos); continue; }
            // on to the end mark
            int q = pos;
            while (q + 4 <= data.length && !(data[q] == (byte) 0xEF && data[q + 1] == (byte) 0xBE && data[q + 2] == (byte) 0xAD && data[q + 3] == (byte) 0xDE)) q++;
            bb.position(Math.min(data.length, q + 4));
        }
        if (!list) System.out.println(written + " pictures -> " + out);
    }
}
