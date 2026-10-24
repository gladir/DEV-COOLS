package java.util.zip;
import java.io.ByteArrayOutputStream;
public final class ZipSupport {
    private ZipSupport() {}
    public static native byte[] inflate0(byte[] in, int off, int len, int[] consumed);
    public static native int crc32(int crc, byte[] b, int off, int len);
    private static final int[] LBASE = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258};
    private static final int[] LEXT = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0};
    private static final int[] DBASE = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577};
    private static final int[] DEXT = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13};

    public static int adler32(int adler, byte[] b, int off, int len) {
        int s1 = adler & 0xffff, s2 = (adler >>> 16) & 0xffff;
        for (int i = 0; i < len; i++) {
            s1 += b[off + i] & 255;
            if (s1 >= 65521) s1 -= 65521;
            s2 += s1;
            if (s2 >= 65521) s2 -= 65521;
        }
        return (s2 << 16) | s1;
    }

    // ----- compression DEFLATE (LZ77 + codes de Huffman fixes) ---------------------
    private static final class BitOut {
        byte[] buf = new byte[1024];
        int n;
        int bits, nbits;
        void put(int v, int count) {
            bits |= v << nbits;
            nbits += count;
            while (nbits >= 8) { emit(bits & 255); bits >>>= 8; nbits -= 8; }
        }
        void putRev(int code, int len) {
            int r = 0;
            for (int i = 0; i < len; i++) { r = (r << 1) | (code & 1); code >>>= 1; }
            put(r, len);
        }
        void align() { if (nbits > 0) { emit(bits & 255); bits = 0; nbits = 0; } }
        void emit(int b) {
            if (n == buf.length) buf = java.util.Arrays.copyOf(buf, n * 2);
            buf[n++] = (byte) b;
        }
    }
    private static void putLit(BitOut o, int sym) {
        if (sym < 144) o.putRev(0x30 + sym, 8);
        else if (sym < 256) o.putRev(0x190 + sym - 144, 9);
        else if (sym < 280) o.putRev(sym - 256, 7);
        else o.putRev(0xC0 + sym - 280, 8);
    }
    public static byte[] deflateRaw(byte[] data, int off, int len, int level) {
        BitOut o = new BitOut();
        if (level == 0 || len == 0) {
            if (len == 0) { o.put(1, 1); o.put(1, 2); putLit(o, 256); o.align(); return java.util.Arrays.copyOf(o.buf, o.n); }
            int pos = 0;
            while (pos < len) {
                int chunk = Math.min(65535, len - pos);
                boolean last = pos + chunk >= len;
                o.put(last ? 1 : 0, 1); o.put(0, 2); o.align();
                o.emit(chunk & 255); o.emit(chunk >> 8); o.emit(~chunk & 255); o.emit((~chunk >> 8) & 255);
                for (int i = 0; i < chunk; i++) o.emit(data[off + pos + i]);
                pos += chunk;
            }
            return java.util.Arrays.copyOf(o.buf, o.n);
        }
        int chain = level <= 3 ? 8 : (level >= 8 ? 256 : 48);
        int[] head = new int[1 << 15];
        java.util.Arrays.fill(head, -1);
        int[] prev = new int[len];
        o.put(1, 1); o.put(1, 2);
        int i = 0;
        while (i < len) {
            int bestLen = 0, bestDist = 0;
            if (i + 2 < len) {
                int h = (((data[off + i] & 255) << 10) ^ ((data[off + i + 1] & 255) << 5) ^ (data[off + i + 2] & 255)) & 0x7fff;
                int cand = head[h];
                int tries = chain;
                int maxLen = Math.min(258, len - i);
                while (cand >= 0 && i - cand <= 32768 && tries-- > 0) {
                    int l = 0;
                    while (l < maxLen && data[off + cand + l] == data[off + i + l]) l++;
                    if (l > bestLen) { bestLen = l; bestDist = i - cand; if (l == maxLen) break; }
                    cand = prev[cand];
                }
                prev[i] = head[h];
                head[h] = i;
            }
            if (bestLen >= 3) {
                int lc = 28;
                while (LBASE[lc] > bestLen) lc--;
                putLit(o, 257 + lc);
                if (LEXT[lc] > 0) o.put(bestLen - LBASE[lc], LEXT[lc]);
                int dc = 29;
                while (DBASE[dc] > bestDist) dc--;
                o.putRev(dc, 5);
                if (DEXT[dc] > 0) o.put(bestDist - DBASE[dc], DEXT[dc]);
                for (int k = 1; k < bestLen; k++) {
                    int p = i + k;
                    if (p + 2 < len) {
                        int h2 = (((data[off + p] & 255) << 10) ^ ((data[off + p + 1] & 255) << 5) ^ (data[off + p + 2] & 255)) & 0x7fff;
                        prev[p] = head[h2];
                        head[h2] = p;
                    }
                }
                i += bestLen;
            } else {
                putLit(o, data[off + i] & 255);
                i++;
            }
        }
        putLit(o, 256);
        o.align();
        return java.util.Arrays.copyOf(o.buf, o.n);
    }
}
