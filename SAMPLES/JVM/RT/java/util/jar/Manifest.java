package java.util.jar;
import java.io.*;
import java.util.*;
public class Manifest implements Cloneable {
    private Attributes attr = new Attributes();
    private Map<String, Attributes> entries = new LinkedHashMap<>();
    public Manifest() { }
    public Manifest(InputStream is) throws IOException { read(is); }
    public Manifest(Manifest man) { attr.putAll(man.getMainAttributes()); entries.putAll(man.getEntries()); }
    public Attributes getMainAttributes() { return attr; }
    public Map<String, Attributes> getEntries() { return entries; }
    public Attributes getAttributes(String name) { return getEntries().get(name); }
    public void clear() { attr.clear(); entries.clear(); }
    private static void writeLine(OutputStream out, String s) throws IOException {
        byte[] b = s.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        int pos = 0;
        boolean first = true;
        while (pos < b.length) {
            int max = first ? 72 : 71;
            int n = Math.min(max, b.length - pos);
            while (pos + n < b.length && (b[pos + n] & 0xC0) == 0x80) n--;
            if (!first) out.write(' ');
            out.write(b, pos, n);
            out.write('\r'); out.write('\n');
            pos += n;
            first = false;
        }
        if (b.length == 0) { out.write('\r'); out.write('\n'); }
    }
    private static void writeAttrs(OutputStream out, Attributes a, boolean main) throws IOException {
        if (main) { String v = a.getValue(Attributes.Name.MANIFEST_VERSION); if (v != null) writeLine(out, "Manifest-Version: " + v); }
        for (Map.Entry<Object, Object> e : a.entrySet()) {
            if (main && e.getKey().equals(Attributes.Name.MANIFEST_VERSION)) continue;
            writeLine(out, e.getKey() + ": " + e.getValue());
        }
        writeLine(out, "");
    }
    public void write(OutputStream out) throws IOException {
        writeAttrs(out, attr, true);
        for (Map.Entry<String, Attributes> e : entries.entrySet()) {
            writeLine(out, "Name: " + e.getKey());
            writeAttrs(out, e.getValue(), false);
        }
        out.flush();
    }
    public void read(InputStream is) throws IOException {
        String all = new String(is.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        List<String> lines = new ArrayList<>();
        for (String l : all.split("\r\n|\n|\r", -1)) {
            if (l.startsWith(" ") && !lines.isEmpty()) lines.set(lines.size() - 1, lines.get(lines.size() - 1) + l.substring(1));
            else lines.add(l);
        }
        Attributes cur = attr;
        for (String l : lines) {
            if (l.isEmpty()) { cur = null; continue; }
            int c = l.indexOf(": ");
            if (c < 0) throw new IOException("invalid header field (line " + l + ")");
            String k = l.substring(0, c), v = l.substring(c + 2);
            if (cur == null) {
                if (!k.equalsIgnoreCase("Name")) throw new IOException("invalid manifest format");
                cur = new Attributes();
                entries.put(v, cur);
            } else cur.putValue(k, v);
        }
    }
    public boolean equals(Object o) { return o instanceof Manifest m && attr.equals(m.getMainAttributes()) && entries.equals(m.getEntries()); }
    public int hashCode() { return attr.hashCode() + entries.hashCode(); }
    public Object clone() { return new Manifest(this); }
}
