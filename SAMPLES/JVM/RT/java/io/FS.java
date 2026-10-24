package java.io;
final class FS {
    private FS() {}
    static native int open(String path, int mode);
    static native int read(int h);
    static native int readBytes(int h, byte[] b, int off, int len);
    static native void write(int h, byte[] b, int off, int len);
    static native void close(int h);
    static native boolean exists(String p);
    static native boolean isDir(String p);
    static native long length(String p);
    static native boolean delete(String p);
    static native boolean mkdir(String p);
    static native boolean rename(String a, String b);
    static native String[] list(String p);
    static native String cwd();
}
