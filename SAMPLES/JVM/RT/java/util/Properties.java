package java.util;
import java.io.*;
public class Properties extends Hashtable<Object, Object> {
    protected Properties defaults;
    private final HashMap<Object, Object> map = new HashMap<>();
    public Properties() { }
    public Properties(Properties defaults) { this.defaults = defaults; }
    public synchronized Object setProperty(String key, String value) { return put(key, value); }
    public synchronized Object put(Object k, Object v) { if (k == null || v == null) throw new NullPointerException(); return map.put(k, v); }
    public synchronized Object get(Object k) { return map.get(k); }
    public synchronized Object remove(Object k) { return map.remove(k); }
    public synchronized boolean containsKey(Object k) { return map.containsKey(k); }
    public synchronized boolean contains(Object v) { return map.containsValue(v); }
    public boolean containsValue(Object v) { return map.containsValue(v); }
    public synchronized int size() { return map.size(); }
    public synchronized boolean isEmpty() { return map.isEmpty(); }
    public synchronized void clear() { map.clear(); }
    public Set<Object> keySet() { return map.keySet(); }
    public Collection<Object> values() { return map.values(); }
    public Set<Map.Entry<Object, Object>> entrySet() { return map.entrySet(); }
    public synchronized Enumeration<Object> keys() { return Collections.enumeration(new ArrayList<>(map.keySet())); }
    public synchronized Enumeration<Object> elements() { return Collections.enumeration(new ArrayList<>(map.values())); }
    public synchronized String toString() { return map.toString(); }
    public synchronized void putAll(Map<?, ?> t) { for (Map.Entry<?, ?> e : t.entrySet()) put(e.getKey(), e.getValue()); }
    public synchronized boolean equals(Object o) { return map.equals(o); }
    public synchronized int hashCode() { return map.hashCode(); }
    public String getProperty(String key) { Object o = get(key); String s = (o instanceof String) ? (String) o : null; return ((s == null) && (defaults != null)) ? defaults.getProperty(key) : s; }
    public String getProperty(String key, String def) { String v = getProperty(key); return v == null ? def : v; }
    public Set<String> stringPropertyNames() { Set<String> s = new TreeSet<>(); for (Object k : keySet()) if (k instanceof String) s.add((String) k); return s; }
    public synchronized void load(Reader r) throws IOException {
        BufferedReader br = new BufferedReader(r);
        String line;
        while ((line = br.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("#") || line.startsWith("!")) continue;
            int i = 0;
            while (i < line.length() && "=: \t".indexOf(line.charAt(i)) < 0) i++;
            String k = line.substring(0, i);
            while (i < line.length() && " \t".indexOf(line.charAt(i)) >= 0) i++;
            if (i < line.length() && (line.charAt(i) == '=' || line.charAt(i) == ':')) i++;
            while (i < line.length() && " \t".indexOf(line.charAt(i)) >= 0) i++;
            put(k, line.substring(i));
        }
    }
    public synchronized void load(InputStream in) throws IOException { load(new InputStreamReader(in)); }
    public void store(Writer w, String comments) throws IOException {
        BufferedWriter bw = new BufferedWriter(w);
        if (comments != null) bw.write("#" + comments + "\n");
        for (Map.Entry<Object, Object> e : entrySet()) bw.write(e.getKey() + "=" + e.getValue() + "\n");
        bw.flush();
    }
    public void store(OutputStream out, String comments) throws IOException { store(new OutputStreamWriter(out), comments); }
    public void list(PrintStream out) { out.println("-- listing properties --"); for (Map.Entry<Object, Object> e : entrySet()) out.println(e.getKey() + "=" + e.getValue()); }
}
