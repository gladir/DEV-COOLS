package java.lang;
import java.io.*;
public final class System {
    private System() {}
    public static final InputStream in = new FileInputStream(0);
    public static PrintStream out = new PrintStream(new FileOutputStream(1), true);
    public static PrintStream err = new PrintStream(new FileOutputStream(2), true);
    public static void setOut(PrintStream p) { out = p; }
    public static void setErr(PrintStream p) { err = p; }
    public static void setIn(InputStream i) { }
    public static native void arraycopy(Object src, int srcPos, Object dest, int destPos, int length);
    public static native long currentTimeMillis();
    public static native long nanoTime();
    public static native int identityHashCode(Object o);
    public static void exit(int status) { Runtime.getRuntime().exit(status); }
    public static void gc() { VM.gc(); }
    public static String getProperty(String key) { return VM.property(key); }
    public static String getProperty(String key, String def) { String v = VM.property(key); return v == null ? def : v; }
    public static String setProperty(String k, String v) { return null; }
    public static String getenv(String name) { return VM.getenv(name); }
    public static java.util.Map<String, String> getenv() { return new java.util.HashMap<>(); }
    public static String lineSeparator() { return "\n"; }
    public static void runFinalization() { }
    public static Console console() { return null; }
}
