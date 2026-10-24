package java.io;
public class File implements Comparable<File>, java.io.Serializable {
    public static final String separator = "/";
    public static final char separatorChar = '/';
    public static final String pathSeparator = ":";
    public static final char pathSeparatorChar = ':';
    private final String path;
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
    public static File createTempFile(String prefix, String suffix) throws IOException { File f = new File("/tmp/" + prefix + System.nanoTime() + (suffix == null ? ".tmp" : suffix)); f.createNewFile(); return f; }
    public int compareTo(File o) { return path.compareTo(o.path); }
    public boolean equals(Object o) { return o instanceof File f && f.path.equals(path); }
    public int hashCode() { return path.hashCode() ^ 1234321; }
    public String toString() { return path; }
}
