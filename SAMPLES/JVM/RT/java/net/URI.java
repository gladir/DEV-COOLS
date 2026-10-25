package java.net;
import java.io.File;
public final class URI implements Comparable<URI>, java.io.Serializable {
    private static final long serialVersionUID = -6052424284110960213L;
    private transient String scheme, fragment, authority, userInfo, host, path, query, schemeSpecificPart;
    private transient int port = -1;
    private volatile String string;
    private URI() { }
    public URI(String str) throws URISyntaxException { parse(str); }
    public URI(String scheme, String userInfo, String host, int port, String path, String query, String fragment) throws URISyntaxException {
        StringBuilder sb = new StringBuilder();
        if (scheme != null) sb.append(scheme).append(':');
        if (host != null) {
            sb.append("//");
            if (userInfo != null) sb.append(userInfo).append('@');
            sb.append(host);
            if (port != -1) sb.append(':').append(port);
        }
        if (path != null) sb.append(quote(path));
        if (query != null) sb.append('?').append(quote(query));
        if (fragment != null) sb.append('#').append(quote(fragment));
        parse(sb.toString());
    }
    public URI(String scheme, String authority, String path, String query, String fragment) throws URISyntaxException {
        StringBuilder sb = new StringBuilder();
        if (scheme != null) sb.append(scheme).append(':');
        if (authority != null) sb.append("//").append(authority);
        if (path != null) sb.append(quote(path));
        if (query != null) sb.append('?').append(quote(query));
        if (fragment != null) sb.append('#').append(quote(fragment));
        parse(sb.toString());
    }
    public URI(String scheme, String host, String path, String fragment) throws URISyntaxException { this(scheme, null, host, -1, path, null, fragment); }
    public URI(String scheme, String ssp, String fragment) throws URISyntaxException {
        StringBuilder sb = new StringBuilder();
        if (scheme != null) sb.append(scheme).append(':');
        if (ssp != null) sb.append(quote(ssp));
        if (fragment != null) sb.append('#').append(quote(fragment));
        parse(sb.toString());
    }
    private static String quote(String s) {
        StringBuilder sb = new StringBuilder();
        byte[] bs = s.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        for (byte b : bs) {
            int c = b & 255;
            if (c < 128 && (Character.isLetterOrDigit(c) || "_-!.~'()*/?:@&=+$,;[]%".indexOf(c) >= 0)) sb.append((char) c);
            else sb.append('%').append(Character.toUpperCase(Character.forDigit(c >> 4, 16))).append(Character.toUpperCase(Character.forDigit(c & 15, 16)));
        }
        return sb.toString();
    }
    public static URI create(String str) {
        try { return new URI(str); } catch (URISyntaxException x) { throw new IllegalArgumentException(x.getMessage(), x); }
    }
    private static String decode(String s) {
        if (s == null || s.indexOf('%') < 0) return s;
        java.io.ByteArrayOutputStream bo = new java.io.ByteArrayOutputStream();
        for (int i = 0; i < s.length(); ) {
            char c = s.charAt(i);
            if (c == '%' && i + 2 < s.length() + 0 && i + 2 <= s.length() - 1 + 0) {
                bo.write(Integer.parseInt(s.substring(i + 1, i + 3), 16));
                i += 3;
            } else {
                byte[] b = String.valueOf(c).getBytes(java.nio.charset.StandardCharsets.UTF_8);
                bo.write(b, 0, b.length);
                i++;
            }
        }
        return new String(bo.toByteArray(), java.nio.charset.StandardCharsets.UTF_8);
    }
    private void parse(String str) throws URISyntaxException {
        string = str;
        int i = 0, n = str.length();
        for (int k = 0; k < n; k++) {
            char c = str.charAt(k);
            if (c == ' ' || c == '"' || c == '<' || c == '>' || c == '\\' || c == '^' || c == '`' || c == '{' || c == '|' || c == '}')
                throw new URISyntaxException(str, "Illegal character in " + (k < str.indexOf('?') || str.indexOf('?') < 0 ? "path" : "query"), k);
        }
        int colon = str.indexOf(':');
        int slash = str.indexOf('/'), qm = str.indexOf('?'), hash = str.indexOf('#');
        int firstDelim = n;
        for (int d : new int[]{slash, qm, hash}) if (d >= 0 && d < firstDelim) firstDelim = d;
        if (colon >= 0 && colon < firstDelim) {
            if (colon == 0) throw new URISyntaxException(str, "Expected scheme name", 0);
            scheme = str.substring(0, colon);
            for (int k = 0; k < scheme.length(); k++) {
                char c = scheme.charAt(k);
                if (!(Character.isLetter(c) || (k > 0 && (Character.isDigit(c) || c == '+' || c == '-' || c == '.'))))
                    throw new URISyntaxException(str, "Illegal character in scheme name", k);
            }
            i = colon + 1;
            if (i == n) throw new URISyntaxException(str, "Expected scheme-specific part", i);
        }
        String rest = str.substring(i);
        int h = rest.indexOf('#');
        if (h >= 0) { fragment = decode(rest.substring(h + 1)); rest = rest.substring(0, h); }
        schemeSpecificPart = decode(rest);
        if (scheme != null && !rest.startsWith("/")) { path = null; return; }
        if (rest.startsWith("//")) {
            int e = rest.length();
            int p = rest.indexOf('/', 2), q = rest.indexOf('?', 2);
            if (p >= 0) e = p; if (q >= 0 && q < e) e = q;
            authority = rest.substring(2, e);
            if (authority.isEmpty()) authority = null;
            if (authority != null) {
                String a = authority;
                int at = a.lastIndexOf('@');
                if (at >= 0) { userInfo = a.substring(0, at); a = a.substring(at + 1); }
                int pc = a.lastIndexOf(':');
                if (pc >= 0 && a.indexOf(']') < pc) {
                    String ps = a.substring(pc + 1);
                    if (!ps.isEmpty()) {
                        try { port = Integer.parseInt(ps); } catch (NumberFormatException ex) { throw new URISyntaxException(str, "Illegal character in authority", i + 2 + pc); }
                    }
                    a = a.substring(0, pc);
                }
                host = a;
                authority = decode(authority);
            }
            rest = rest.substring(e);
        }
        int q = rest.indexOf('?');
        if (q >= 0) { query = decode(rest.substring(q + 1)); rest = rest.substring(0, q); }
        path = decode(rest);
    }
    public String getScheme() { return scheme; }
    public boolean isAbsolute() { return scheme != null; }
    public boolean isOpaque() { return path == null; }
    public String getRawSchemeSpecificPart() { return schemeSpecificPart; }
    public String getSchemeSpecificPart() { return schemeSpecificPart; }
    public String getAuthority() { return authority; }
    public String getRawAuthority() { return authority; }
    public String getUserInfo() { return userInfo; }
    public String getHost() { return host; }
    public int getPort() { return port; }
    public String getPath() { return path; }
    public String getRawPath() { return path; }
    public String getQuery() { return query; }
    public String getRawQuery() { return query; }
    public String getFragment() { return fragment; }
    public String getRawFragment() { return fragment; }
    public URI normalize() {
        if (path == null || path.isEmpty()) return this;
        boolean abs = path.startsWith("/");
        java.util.ArrayList<String> segs = new java.util.ArrayList<>();
        String[] parts = path.split("/", -1);
        for (int i = 0; i < parts.length; i++) {
            String s = parts[i];
            if (s.equals(".")) { if (i == parts.length - 1) segs.add(""); continue; }
            if (s.equals("..")) {
                if (!segs.isEmpty() && !segs.get(segs.size() - 1).equals("..") && !(segs.size() == 1 && segs.get(0).isEmpty() && abs)) { segs.remove(segs.size() - 1); if (i == parts.length - 1) segs.add(""); continue; }
                if (abs) continue;
            }
            if (s.isEmpty() && i > 0 && i < parts.length - 1) continue;
            segs.add(s);
        }
        String np = String.join("/", segs);
        if (abs && !np.startsWith("/")) np = "/" + np;
        if (np.equals(path)) return this;
        URI r = new URI();
        r.scheme = scheme; r.authority = authority; r.userInfo = userInfo; r.host = host; r.port = port; r.query = query; r.fragment = fragment; r.path = np;
        r.schemeSpecificPart = null;
        r.rebuild();
        return r;
    }
    private void rebuild() {
        StringBuilder sb = new StringBuilder();
        if (scheme != null) sb.append(scheme).append(':');
        if (path == null) sb.append(schemeSpecificPart);
        else {
            if (authority != null) sb.append("//").append(authority);
            sb.append(quote(path));
            if (query != null) sb.append('?').append(quote(query));
        }
        if (fragment != null) sb.append('#').append(quote(fragment));
        string = sb.toString();
        if (schemeSpecificPart == null) {
            int c = string.indexOf(':');
            int h = string.indexOf('#');
            schemeSpecificPart = decode(string.substring(c + 1, h < 0 ? string.length() : h));
        }
    }
    public URI resolve(URI uri) {
        if (uri.isOpaque() || isOpaque()) return uri;
        if (uri.scheme != null) return uri;
        if (uri.authority == null && uri.path.isEmpty() && uri.fragment != null && uri.query == null) {
            URI r = new URI(); r.scheme = scheme; r.authority = authority; r.userInfo = userInfo; r.host = host; r.port = port; r.path = path; r.query = query; r.fragment = uri.fragment; r.rebuild(); return r;
        }
        URI r = new URI();
        r.scheme = scheme; r.fragment = uri.fragment;
        if (uri.authority != null) { r.authority = uri.authority; r.userInfo = uri.userInfo; r.host = uri.host; r.port = uri.port; r.path = uri.path; r.query = uri.query; }
        else {
            r.authority = authority; r.userInfo = userInfo; r.host = host; r.port = port;
            r.query = uri.query;
            if (uri.path.startsWith("/")) r.path = uri.path;
            else {
                String base = path;
                int i = base.lastIndexOf('/');
                r.path = (i >= 0 ? base.substring(0, i + 1) : "") + uri.path;
            }
        }
        r.rebuild();
        return r.normalize();
    }
    public URI resolve(String str) { return resolve(URI.create(str)); }
    public URI relativize(URI uri) {
        if (uri.isOpaque() || isOpaque()) return uri;
        if (!java.util.Objects.equals(scheme, uri.scheme) || !java.util.Objects.equals(authority, uri.authority)) return uri;
        String bp = path.endsWith("/") ? path : path + "/";
        if (!uri.path.startsWith(bp) && !uri.path.equals(path)) return uri;
        URI r = new URI();
        r.path = uri.path.equals(path) ? "" : uri.path.substring(bp.length());
        r.query = uri.query; r.fragment = uri.fragment;
        r.rebuild();
        return r;
    }
    public URL toURL() throws MalformedURLException {
        if (!isAbsolute()) throw new IllegalArgumentException("URI is not absolute");
        return new URL(toString());
    }
    public String toASCIIString() { return toString(); }
    public String toString() {
        if (string == null) rebuild();
        return string;
    }
    public boolean equals(Object ob) {
        if (ob == this) return true;
        if (!(ob instanceof URI)) return false;
        URI that = (URI) ob;
        if (this.isOpaque() != that.isOpaque()) return false;
        if (!equalIgnoringCase(this.scheme, that.scheme)) return false;
        if (!java.util.Objects.equals(this.fragment, that.fragment)) return false;
        if (this.isOpaque()) return java.util.Objects.equals(this.schemeSpecificPart, that.schemeSpecificPart);
        if (!java.util.Objects.equals(this.path, that.path)) return false;
        if (!java.util.Objects.equals(this.query, that.query)) return false;
        if (this.authority == that.authority) return true;
        if (this.host != null) return java.util.Objects.equals(userInfo, that.userInfo) && equalIgnoringCase(host, that.host) && port == that.port;
        return java.util.Objects.equals(authority, that.authority);
    }
    private static boolean equalIgnoringCase(String a, String b) { return a == null ? b == null : a.equalsIgnoreCase(b); }
    public int hashCode() {
        int h = scheme == null ? 0 : scheme.toLowerCase().hashCode();
        h = h * 31 + java.util.Objects.hashCode(fragment);
        if (isOpaque()) return h * 31 + java.util.Objects.hashCode(schemeSpecificPart);
        h = h * 31 + java.util.Objects.hashCode(path);
        h = h * 31 + java.util.Objects.hashCode(query);
        if (host != null) h = h * 31 + java.util.Objects.hashCode(userInfo) * 31 + host.toLowerCase().hashCode() + port * 31;
        else h = h * 31 + java.util.Objects.hashCode(authority);
        return h;
    }
    public int compareTo(URI that) { return toString().compareTo(that.toString()); }
    private void writeObject(java.io.ObjectOutputStream os) throws java.io.IOException { os.defaultWriteObject(); os.writeObject(toString()); }
    private void readObject(java.io.ObjectInputStream is) throws java.io.IOException, ClassNotFoundException {
        is.defaultReadObject();
        String s = (String) is.readObject();
        try { parse(s); } catch (URISyntaxException x) { throw new java.io.InvalidObjectException(x.getMessage()); }
    }
}
