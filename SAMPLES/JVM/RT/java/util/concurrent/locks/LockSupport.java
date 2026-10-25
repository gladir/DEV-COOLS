package java.util.concurrent.locks;
public class LockSupport {
    public static void park() { Thread.yield(); }
    public static void parkNanos(long n) { try { Thread.sleep(Math.max(1, n / 1000000)); } catch (InterruptedException e) { } }
    public static void unpark(Thread t) { }
}
