package java.lang;
public class Object {
    public Object() {}
    public final native Class<?> getClass();
    public native int hashCode();
    public boolean equals(Object obj) { return this == obj; }
    protected native Object clone() throws CloneNotSupportedException;
    public String toString() { return getClass().getName() + "@" + Integer.toHexString(hashCode()); }
    public final native void notify();
    public final native void notifyAll();
    public final native void wait() throws InterruptedException;
    public final native void wait(long timeout) throws InterruptedException;
    protected void finalize() throws Throwable { }
}
