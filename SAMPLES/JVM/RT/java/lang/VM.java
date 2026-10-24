package java.lang;
public final class VM {
    private VM() {}
    public static native void write(int fd, String s);
    public static native void writeByte(int fd, int b);
    public static native void flush();
    public static native int readByte();
    public static native void sleep(long ms);
    public static native String property(String key);
    public static native String getenv(String key);
    public static native void gc();
    public static native long freeMemory();
    public static native long totalMemory();
    public static native int ncpu();
    public static native String fixed(double d, int prec);
    public static native Object newInstance(Class<?> c);
    public static native Object newArray(Class<?> c, int n);
    public static Runnable pumpHook;
}
