package java.util;
public class Base64 {
    private static final String STD = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    private static final String URL = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    public static Encoder getEncoder() { return new Encoder(STD, true); }
    public static Encoder getUrlEncoder() { return new Encoder(URL, true); }
    public static Decoder getDecoder() { return new Decoder(STD); }
    public static Decoder getUrlDecoder() { return new Decoder(URL); }
    public static class Encoder {
        private final String alpha; private final boolean pad;
        Encoder(String a, boolean p) { alpha = a; pad = p; }
        public Encoder withoutPadding() { return new Encoder(alpha, false); }
        public String encodeToString(byte[] src) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < src.length; i += 3) {
                int b0 = src[i] & 0xff, b1 = i + 1 < src.length ? src[i + 1] & 0xff : 0, b2 = i + 2 < src.length ? src[i + 2] & 0xff : 0;
                sb.append(alpha.charAt(b0 >> 2)).append(alpha.charAt(((b0 & 3) << 4) | (b1 >> 4)));
                if (i + 1 < src.length) sb.append(alpha.charAt(((b1 & 15) << 2) | (b2 >> 6))); else if (pad) sb.append('=');
                if (i + 2 < src.length) sb.append(alpha.charAt(b2 & 63)); else if (pad) sb.append('=');
            }
            return sb.toString();
        }
        public byte[] encode(byte[] src) { return encodeToString(src).getBytes(); }
    }
    public static class Decoder {
        private final String alpha;
        Decoder(String a) { alpha = a; }
        public byte[] decode(String s) {
            java.io.ByteArrayOutputStream bo = new java.io.ByteArrayOutputStream();
            int acc = 0, bits = 0;
            for (int i = 0; i < s.length(); i++) {
                char c = s.charAt(i);
                if (c == '=') break;
                int v = alpha.indexOf(c);
                if (v < 0) throw new IllegalArgumentException("Illegal base64 character " + Integer.toHexString(c));
                acc = (acc << 6) | v; bits += 6;
                if (bits >= 8) { bits -= 8; bo.write((acc >> bits) & 0xff); }
            }
            return bo.toByteArray();
        }
        public byte[] decode(byte[] b) { return decode(new String(b)); }
    }
}
