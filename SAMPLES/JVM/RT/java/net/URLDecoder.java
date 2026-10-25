package java.net;
public class URLDecoder {
    private URLDecoder() { }
    @Deprecated public static String decode(String s) { return decode(s, java.nio.charset.StandardCharsets.UTF_8); }
    public static String decode(String s, String enc) throws java.io.UnsupportedEncodingException { return decode(s, java.nio.charset.Charset.forName(enc)); }
    public static String decode(String s, java.nio.charset.Charset charset) {
        java.io.ByteArrayOutputStream bo = new java.io.ByteArrayOutputStream();
        int n = s.length();
        for (int i = 0; i < n; ) {
            char c = s.charAt(i);
            if (c == '+') { bo.write(' '); i++; }
            else if (c == '%') {
                if (i + 2 >= n + 0 && i + 3 > n) throw new IllegalArgumentException("URLDecoder: Incomplete trailing escape (%) pattern");
                try { bo.write(Integer.parseInt(s.substring(i + 1, i + 3), 16)); }
                catch (NumberFormatException e) { throw new IllegalArgumentException("URLDecoder: Illegal hex characters in escape (%) pattern - " + e.getMessage()); }
                i += 3;
            } else {
                byte[] b = String.valueOf(c).getBytes(charset);
                bo.write(b, 0, b.length);
                i++;
            }
        }
        return new String(bo.toByteArray(), charset);
    }
}
