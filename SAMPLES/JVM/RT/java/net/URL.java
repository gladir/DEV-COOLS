package java.net;
import java.io.*;
public final class URL implements java.io.Serializable {
    private static final long serialVersionUID = -7627629688361524110L;
    private String protocol, host, file, query, authority, path, ref;
    private int port = -1;
    public URL(String protocol, String host, int port, String file) throws MalformedURLException {
        this(protocol + ":" + (host != null && !host.isEmpty() ? "//" + host + (port >= 0 ? ":" + port : "") : "") + file);
    }
    public URL(String protocol, String host, String file) throws MalformedURLException { this(protocol, host, -1, file); }
    public URL(String spec) throws MalformedURLException {
        if (spec == null) throw new MalformedURLException("Cannot invoke \"String.length()\" because \"spec\" is null");
        String s = spec.trim();
        int colon = s.indexOf(':');
        if (colon <= 0) throw new MalformedURLException("no protocol: " + spec);
        protocol = s.substring(0, colon).toLowerCase();
        for (int i = 0; i < protocol.length(); i++) {
            char c = protocol.charAt(i);
            if (!(Character.isLetterOrDigit(c) || c == '+' || c == '-' || c == '.')) throw new MalformedURLException("no protocol: " + spec);
        }
        if (!(protocol.equals("file") || protocol.equals("jar") || protocol.equals("http") || protocol.equals("https") || protocol.equals("ftp")))
            throw new MalformedURLException("unknown protocol: " + protocol);
        String rest = s.substring(colon + 1);
        int h = rest.indexOf('#');
        if (h >= 0) { ref = rest.substring(h + 1); rest = rest.substring(0, h); }
        if (protocol.equals("jar")) {
            if (rest.indexOf("!/") < 0) throw new MalformedURLException("no !/ in spec");
            file = rest;
            path = rest;
            host = ""; authority = null;
            return;
        }
        if (rest.startsWith("//")) {
            int e = rest.indexOf('/', 2);
            String auth = e < 0 ? rest.substring(2) : rest.substring(2, e);
            rest = e < 0 ? "" : rest.substring(e);
            authority = auth.isEmpty() ? null : auth;
            String hp = auth;
            int at = hp.lastIndexOf('@');
            if (at >= 0) hp = hp.substring(at + 1);
            int pc = hp.lastIndexOf(':');
            if (pc >= 0 && hp.indexOf(']') < pc) {
                try { port = Integer.parseInt(hp.substring(pc + 1)); } catch (NumberFormatException ex) { throw new MalformedURLException("For input string: \"" + hp.substring(pc + 1) + "\""); }
                hp = hp.substring(0, pc);
            }
            host = hp;
        } else host = "";
        int q = rest.indexOf('?');
        if (q >= 0) { query = rest.substring(q + 1); path = rest.substring(0, q); file = rest; }
        else { path = rest; file = rest; }
    }
    public String getProtocol() { return protocol; }
    public String getHost() { return host; }
    public int getPort() { return port; }
    public int getDefaultPort() { return protocol.equals("http") ? 80 : protocol.equals("https") ? 443 : protocol.equals("ftp") ? 21 : -1; }
    public String getFile() { return file; }
    public String getPath() { return path; }
    public String getQuery() { return query; }
    public String getRef() { return ref; }
    public String getAuthority() { return authority; }
    public String getUserInfo() { return null; }
    public String toExternalForm() {
        StringBuilder sb = new StringBuilder(protocol).append(':');
        if (authority != null && !protocol.equals("jar")) sb.append("//").append(authority);
        else if (protocol.equals("file") && host != null && host.isEmpty() && file.startsWith("/")) sb.append("");
        sb.append(file == null ? "" : file);
        if (ref != null) sb.append('#').append(ref);
        return sb.toString();
    }
    public String toString() { return toExternalForm(); }
    public URI toURI() throws URISyntaxException { return new URI(toString()); }
    public boolean equals(Object o) { return o instanceof URL u && toExternalForm().equals(u.toExternalForm()); }
    public int hashCode() { return toExternalForm().hashCode(); }
    public final InputStream openStream() throws IOException {
        if (protocol.equals("file")) return new FileInputStream(URLDecoder.decode(path, "UTF-8"));
        if (protocol.equals("jar")) {
            int i = file.indexOf("!/");
            String jar = file.substring(0, i);
            String entry = URLDecoder.decode(file.substring(i + 2), "UTF-8");
            if (jar.startsWith("file:")) jar = jar.substring(5);
            java.util.jar.JarFile jf = new java.util.jar.JarFile(jar);
            java.util.zip.ZipEntry e = jf.getEntry(entry);
            if (e == null) throw new FileNotFoundException("JAR entry " + entry + " not found in " + jar);
            InputStream in = jf.getInputStream(e);
            jf.close();
            return in;
        }
        throw new IOException("Unsupported protocol: " + protocol);
    }
}
