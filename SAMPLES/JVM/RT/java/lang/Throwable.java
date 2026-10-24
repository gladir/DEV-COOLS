package java.lang;
import java.io.PrintStream;
import java.io.PrintWriter;
public class Throwable implements java.io.Serializable {
    private Object backtrace;
    private String detailMessage;
    private Throwable cause = this;
    private StackTraceElement[] stackTrace;
    private java.util.List<Throwable> suppressed;
    public Throwable() { fillInStackTrace(); }
    public Throwable(String message) { fillInStackTrace(); detailMessage = message; }
    public Throwable(String message, Throwable cause) { fillInStackTrace(); detailMessage = message; this.cause = cause; }
    public Throwable(Throwable cause) { fillInStackTrace(); detailMessage = (cause == null ? null : cause.toString()); this.cause = cause; }
    protected Throwable(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) {
        fillInStackTrace(); detailMessage = message; this.cause = cause;
    }
    public String getMessage() { return detailMessage; }
    public String getLocalizedMessage() { return getMessage(); }
    public synchronized Throwable getCause() { return (cause == this ? null : cause); }
    public synchronized Throwable initCause(Throwable cause) {
        if (this.cause != this) throw new IllegalStateException("Can't overwrite cause with " + java.util.Objects.toString(cause, "a null"), this);
        if (cause == this) throw new IllegalArgumentException("Self-causation not permitted", this);
        this.cause = cause;
        return this;
    }
    public String toString() {
        String s = getClass().getName();
        String message = getLocalizedMessage();
        return (message != null) ? (s + ": " + message) : s;
    }
    public native Throwable fillInStackTrace();
    private static native StackTraceElement[] elements(Object bt);
    public StackTraceElement[] getStackTrace() {
        if (stackTrace == null) stackTrace = elements(backtrace);
        return stackTrace.clone();
    }
    public void setStackTrace(StackTraceElement[] st) { stackTrace = st.clone(); }
    public void printStackTrace() { printStackTrace(System.err); }
    public void printStackTrace(PrintStream s) {
        s.println(this);
        StackTraceElement[] trace = getStackTrace();
        for (StackTraceElement e : trace) s.println("\tat " + e);
        if (suppressed != null) for (Throwable t : suppressed) { s.print("\tSuppressed: "); t.printStackTrace(s); }
        Throwable ourCause = getCause();
        if (ourCause != null) {
            s.print("Caused by: ");
            ourCause.printStackTrace(s);
        }
    }
    public void printStackTrace(PrintWriter s) {
        s.println(this);
        for (StackTraceElement e : getStackTrace()) s.println("\tat " + e);
        Throwable ourCause = getCause();
        if (ourCause != null) { s.print("Caused by: "); ourCause.printStackTrace(s); }
    }
    public final synchronized void addSuppressed(Throwable exception) {
        if (exception == this) throw new IllegalArgumentException("Self-suppression not permitted", exception);
        if (exception == null) throw new NullPointerException("Cannot suppress a null exception.");
        if (suppressed == null) suppressed = new java.util.ArrayList<>();
        suppressed.add(exception);
    }
    public final synchronized Throwable[] getSuppressed() {
        if (suppressed == null) return new Throwable[0];
        return suppressed.toArray(new Throwable[0]);
    }
}
