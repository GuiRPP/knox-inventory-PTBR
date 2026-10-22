import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.util.*;

/**
 * Loudness of WAV files as heard, for levelling short sounds against each other:
 * K-weighted (the ITU-R BS.1770 pre-filter: a high shelf near 1.7 kHz, a high-pass
 * near 38 Hz, re-derived for the file's own rate), then the mean power of the
 * loudest 400 ms (a short sound is as loud as its loudest moment), in dB.
 * Prints "file<TAB>dB<TAB>seconds" per file.
 *
 *   java Loudness.java <a.wav> <b.wav> ...   (or a folder: every .wav in it)
 */
public class Loudness {
    public static void main(String[] args) throws Exception {
        List<Path> files = new ArrayList<>();
        for (String a : args) {
            Path p = Paths.get(a);
            if (Files.isDirectory(p)) {
                try (DirectoryStream<Path> ds = Files.newDirectoryStream(p, "*.wav")) { for (Path f : ds) files.add(f); }
            } else files.add(p);
        }
        Collections.sort(files);
        for (Path f : files) {
            try {
                Wav w = read(f);
                System.out.printf(Locale.ROOT, "%s\t%.2f\t%.2f%n", f.getFileName(), loudness(w), w.s.length / (double) w.rate);
            } catch (Exception e) {
                System.out.println(f.getFileName() + "\tERR\t" + e.getMessage());
            }
        }
    }

    static class Wav { double[] s; int rate; }

    /** PCM 16-bit or float 32-bit, any channels (mixed to mono). */
    static Wav read(Path p) throws IOException {
        ByteBuffer b = ByteBuffer.wrap(Files.readAllBytes(p)).order(ByteOrder.LITTLE_ENDIAN);
        b.position(12);
        int fmt = 1, ch = 1, rate = 44100, bits = 16;
        while (b.remaining() >= 8) {
            byte[] id = new byte[4];
            b.get(id);
            int len = b.getInt();
            String name = new String(id, "ASCII");
            if (name.equals("fmt ")) {
                int at = b.position();
                fmt = b.getShort() & 0xffff; ch = b.getShort(); rate = b.getInt(); b.getInt(); b.getShort(); bits = b.getShort();
                if (fmt == 0xFFFE) fmt = (bits == 32) ? 3 : 1;
                b.position(at + len);
            } else if (name.equals("data")) {
                int frames = len / (bits / 8) / ch;
                double[] s = new double[frames];
                for (int i = 0; i < frames; i++) {
                    double v = 0;
                    for (int c = 0; c < ch; c++) {
                        if (fmt == 3) v += b.getFloat();
                        else if (bits == 16) v += b.getShort() / 32768.0;
                        else if (bits == 24) { int x = (b.get() & 0xff) | ((b.get() & 0xff) << 8) | (b.get() << 16); v += x / 8388608.0; }
                        else v += b.getInt() / 2147483648.0;
                    }
                    s[i] = v / ch;
                }
                Wav w = new Wav(); w.s = s; w.rate = rate;
                return w;
            } else {
                b.position(b.position() + len + (len & 1));
            }
        }
        throw new IOException("no data");
    }

    static double loudness(Wav w) {
        double[] k = kWeight(w.s, w.rate);
        int win = (int) (0.4 * w.rate);
        if (k.length <= win) {
            double sum = 0;
            for (double v : k) sum += v * v;
            return 10 * Math.log10(sum / win + 1e-12) - 0.691;   // (a sound shorter than the window: its energy over it)
        }
        double sum = 0, best = 0;
        for (int i = 0; i < k.length; i++) {
            sum += k[i] * k[i];
            if (i >= win) sum -= k[i - win] * k[i - win];
            if (i >= win - 1) best = Math.max(best, sum);
        }
        return 10 * Math.log10(best / win + 1e-12) - 0.691;
    }

    /** BS.1770 K-weighting for any rate (the two biquads from their analog prototypes). */
    static double[] kWeight(double[] x, int fs) {
        double[] y = new double[x.length];
        // stage 1: high shelf
        double f0 = 1681.974450955533, G = 3.999843853973347, Q = 0.7071752369554196;
        double K = Math.tan(Math.PI * f0 / fs), Vh = Math.pow(10, G / 20), Vb = Math.pow(Vh, 0.4996667741545416);
        double a0 = 1 + K / Q + K * K;
        double b0 = (Vh + Vb * K / Q + K * K) / a0, b1 = 2 * (K * K - Vh) / a0, b2 = (Vh - Vb * K / Q + K * K) / a0;
        double a1 = 2 * (K * K - 1) / a0, a2 = (1 - K / Q + K * K) / a0;
        double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
        for (int i = 0; i < x.length; i++) {
            double v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
            x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
        }
        // stage 2: high-pass
        f0 = 38.13547087602444; Q = 0.5003270373238773;
        K = Math.tan(Math.PI * f0 / fs);
        a0 = 1 + K / Q + K * K;
        a1 = 2 * (K * K - 1) / a0; a2 = (1 - K / Q + K * K) / a0;
        double[] z = new double[x.length];
        x1 = x2 = y1 = y2 = 0;
        for (int i = 0; i < y.length; i++) {
            double v = (y[i] - 2 * x1 + x2) / a0 - a1 * y1 - a2 * y2;
            x2 = x1; x1 = y[i]; y2 = y1; y1 = v; z[i] = v;
        }
        return z;
    }
}
