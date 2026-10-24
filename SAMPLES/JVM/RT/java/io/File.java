package java.io;
public class File implements Comparable<File>, java.io.Serializable {
    private static final long serialVersionUID = 301077366599181567L;
    public static final String separator = "/";
    public static final char separatorChar = '/';
    public static final String pathSeparator = ":";
    public static final char pathSeparatorChar = ':';
    private String path;
    private synchronized void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException { s.defaultWriteObject(); s.writeChar(separatorChar); }
    private synchronized void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException { s.defaultReadObject(); char sep = s.readChar(); if (sep != separatorChar) path = path.replace(sep, separatorChar); }
    public File(String path) { if (path == null) throw new NullPointerException(); this.path = path.replace('\\', '/'); }
    public File(String parent, String child) { this(parent == null ? child : (parent.endsWith("/") ? parent + child : parent + "/" + child)); }
    public File(File parent, String child) { this(parent == null ? child : parent.path + "/" + child); }
    public String getPath() { return path; }
    public String getName() { int i = path.lastIndexOf('/'); return i < 0 ? path : path.substring(i + 1); }
    public String getParent() { int i = path.lastIndexOf('/'); return i < 0 ? null : (i == 0 ? "/" : path.substring(0, i)); }
    public File getParentFile() { String p = getParent(); return p == null ? null : new File(p); }
    public boolean isAbsolute() { return path.startsWith("/") || (path.length() > 1 && path.charAt(1) == ':'); }
    public String getAbsolutePath() { return isAbsolute() ? path : FS.cwd().replace('\\', '/') + "/" + path; }
    public File getAbsoluteFile() { return new File(getAbsolutePath()); }
    public String getCanonicalPath() throws IOException { return getAbsolutePath(); }
    public boolean exists() { return FS.exists(path); }
    public boolean isFile() { return exists() && !FS.isDir(path); }
    public boolean isDirectory() { return FS.isDir(path); }
    public boolean canRead() { return exists(); }
    public boolean canWrite() { return true; }
    public boolean isHidden() { return getName().startsWith("."); }
    public long length() { return FS.length(path); }
    public long lastModified() { return 0; }
    public boolean delete() { return FS.delete(path); }
    public void deleteOnExit() { }
    public boolean mkdir() { return FS.mkdir(path); }
    public boolean mkdirs() {
        if (exists()) return false;
        File p = getParentFile();
        if (p != null && !p.exists()) p.mkdirs();
        return mkdir();
    }
    public boolean renameTo(File dest) { return FS.rename(path, dest.path); }
    public boolean createNewFile() throws IOException {
        if (exists()) return false;
        int h = FS.open(path, 1);
        if (h < 0) throw new IOException("No such file or directory");
        FS.close(h);
        return true;
    }
    public String[] list() { return FS.list(path); }
    public File[] listFiles() {
        String[] n = list();
        if (n == null) return null;
        java.util.Arrays.sort(n);
        File[] r = new File[n.length];
        for (int i = 0; i < n.length; i++) r[i] = new File(this, n[i]);
        return r;
    }
    public File[] listFiles(FileFilter f) { File[] a = listFiles(); if (a == null) return null; java.util.ArrayList<File> l = new java.util.ArrayList<>(); for (File x : a) if (f.accept(x)) l.add(x); return l.toArray(new File[0]); }
    public java.nio.file.Path toPath() { return new java.nio.file.Path(path); }
    public static File createTempFile(String prefix, String suffix) throws IOException { return createTempFile(prefix, suffix, null); }
    public static File createTempFile(String prefix, String suffix, File directory) throws IOException {
        if (prefix.length() < 3) throw new IllegalArgumentException("Prefix string \"" + prefix + "\" too short: length must be at least 3");
        return tempFile0(prefix, suffix, directory);
    }
    public static File tempFile0(String prefix, String suffix, File directory) throws IOException {
        String dir = directory != null ? directory.getPath() : System.getProperty("java.io.tmpdir", "/tmp");
        java.util.Random r = new java.util.Random(System.nanoTime());
        File f;
        do {
            f = new File(dir + (dir.endsWith("/") ? "" : "/") + (prefix == null ? "" : prefix) + Long.toUnsignedString(r.nextLong()) + (suffix == null ? ".tmp" : suffix));
        } while (f.exists());
        if (!f.createNewFile()) throw new IOException("Unable to create temporary file");
        return f;
    }
    public int compareTo(File o) { return path.compareTo(o.path); }
    public boolean equals(Object o) { return o instanceof File f && f.path.equals(path); }
    public int hashCode() { return path.hashCode() ^ 1234321; }
    public String toString() { return path; }
}
