package java.net;
public class URLEncoder {
    private URLEncoder() { }
    @Deprecated public static String encode(String s) { return encode(s, java.nio.charset.StandardCharsets.UTF_8); }
    public static String encode(String s, String enc) throws java.io.UnsupportedEncodingException {
        return encode(s, java.nio.charset.Charset.forName(enc));
    }
    public static String encode(String s, java.nio.charset.Charset charset) {
        StringBuilder out = new StringBuilder(s.length());
        for (byte b : s.getBytes(charset)) {
            int c = b & 255;
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '*') out.append((char) c);
            else if (c == ' ') out.append('+');
            else out.append('%').append(Character.toUpperCase(Character.forDigit(c >> 4, 16))).append(Character.toUpperCase(Character.forDigit(c & 15, 16)));
        }
        return out.toString();
    }
}
