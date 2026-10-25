package java.lang;
public class Runtime {
    private static final Runtime cur = new Runtime();
    private Runtime() {}
    public static Runtime getRuntime() { return cur; }
    public void exit(int status) { VM.flush(); halt0(status); }
    public void halt(int status) { halt0(status); }
    private static native void halt0(int status);
    public long freeMemory() { return VM.freeMemory(); }
    public long totalMemory() { return VM.totalMemory(); }
    public long maxMemory() { return VM.totalMemory(); }
    public int availableProcessors() { return VM.ncpu(); }
    public void gc() { VM.gc(); }
    public void addShutdownHook(Thread t) { }
}
