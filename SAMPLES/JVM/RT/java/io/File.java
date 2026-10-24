package java.io;
public class File implements Comparable<File> {
    public static final String separator = "/";
    public static final char separatorChar = '/';
    private final String path;
    public File(String path) { this.path = path; }
    public File(String parent, String child) { this.path = parent + "/" + child; }
    public File(File parent, String child) { this.path = parent.path + "/" + child; }
    public String getPath() { return path; }
    public String getName() { int i = path.lastIndexOf('/'); return i < 0 ? path : path.substring(i + 1); }
    public String getAbsolutePath() { return path; }
    public boolean exists() { return false; }
    public boolean isFile() { return false; }
    public boolean isDirectory() { return false; }
    public int compareTo(File o) { return path.compareTo(o.path); }
    public String toString() { return path; }
}
