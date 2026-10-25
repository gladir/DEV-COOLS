package java.nio.file;
public class Path implements Comparable<Path> {
    private final String p;
    public Path(String p) { this.p = p; }
    public static Path of(String first, String... more) { StringBuilder sb = new StringBuilder(first); for (String m : more) sb.append('/').append(m); return new Path(sb.toString()); }
    public Path getFileName() { int i = p.lastIndexOf('/'); return new Path(i < 0 ? p : p.substring(i + 1)); }
    public Path getParent() { int i = p.lastIndexOf('/'); return i <= 0 ? null : new Path(p.substring(0, i)); }
    public Path resolve(String o) { return new Path(p.endsWith("/") ? p + o : p + "/" + o); }
    public Path resolve(Path o) { return resolve(o.p); }
    public Path toAbsolutePath() { return new Path(new java.io.File(p).getAbsolutePath()); }
    public java.io.File toFile() { return new java.io.File(p); }
    public boolean startsWith(String s) { return p.startsWith(s); }
    public boolean endsWith(String s) { return p.endsWith(s); }
    public int compareTo(Path o) { return p.compareTo(o.p); }
    public boolean equals(Object o) { return o instanceof Path q && q.p.equals(p); }
    public int hashCode() { return p.hashCode(); }
    public String toString() { return p; }
}
