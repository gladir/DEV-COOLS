package java.io;
final class Sha1 {
    private Sha1() {}
    static byte[] digest(byte[] msg) {
        int h0 = 0x67452301, h1 = 0xEFCDAB89, h2 = 0x98BADCFE, h3 = 0x10325476, h4 = 0xC3D2E1F0;
        int ml = msg.length;
        int padded = ((ml + 8) / 64 + 1) * 64;
        byte[] m = new byte[padded];
        System.arraycopy(msg, 0, m, 0, ml);
        m[ml] = (byte) 0x80;
        long bits = (long) ml * 8;
        for (int i = 0; i < 8; i++) m[padded - 1 - i] = (byte) (bits >>> (8 * i));
        int[] w = new int[80];
        for (int off = 0; off < padded; off += 64) {
            for (int i = 0; i < 16; i++)
                w[i] = ((m[off + 4 * i] & 255) << 24) | ((m[off + 4 * i + 1] & 255) << 16) | ((m[off + 4 * i + 2] & 255) << 8) | (m[off + 4 * i + 3] & 255);
            for (int i = 16; i < 80; i++) { int x = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]; w[i] = (x << 1) | (x >>> 31); }
            int a = h0, b = h1, c = h2, d = h3, e = h4;
            for (int i = 0; i < 80; i++) {
                int f, k;
                if (i < 20) { f = (b & c) | (~b & d); k = 0x5A827999; }
                else if (i < 40) { f = b ^ c ^ d; k = 0x6ED9EBA1; }
                else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; }
                else { f = b ^ c ^ d; k = 0xCA62C1D6; }
                int t = ((a << 5) | (a >>> 27)) + f + e + k + w[i];
                e = d; d = c; c = (b << 30) | (b >>> 2); b = a; a = t;
            }
            h0 += a; h1 += b; h2 += c; h3 += d; h4 += e;
        }
        byte[] r = new byte[20];
        int[] hs = {h0, h1, h2, h3, h4};
        for (int i = 0; i < 5; i++) for (int j = 0; j < 4; j++) r[4 * i + j] = (byte) (hs[i] >>> (24 - 8 * j));
        return r;
    }
}
