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
    public StackTraceElement[] getStackTrace() { return getOurStackTrace().clone(); }
    public void setStackTrace(StackTraceElement[] st) { stackTrace = st.clone(); }
    public void printStackTrace() { printStackTrace(System.err); }
    public void printStackTrace(PrintStream s) { s.print(traceText()); }
    public void printStackTrace(PrintWriter s) { s.print(traceText()); }
    private String traceText() {
        StringBuilder sb = new StringBuilder();
        java.util.ArrayList<Throwable> dejaVu = new java.util.ArrayList<>();
        dejaVu.add(this);
        sb.append(this).append('\n');
        StackTraceElement[] trace = getOurStackTrace();
        for (StackTraceElement e : trace) sb.append("\tat ").append(e).append('\n');
        for (Throwable se : getSuppressed()) se.printEnclosed(sb, trace, "Suppressed: ", "\t", dejaVu);
        Throwable ourCause = getCause();
        if (ourCause != null) ourCause.printEnclosed(sb, trace, "Caused by: ", "", dejaVu);
        return sb.toString();
    }
    private StackTraceElement[] getOurStackTrace() {
        if (stackTrace == null) stackTrace = elements(backtrace);
        return stackTrace;
    }
    private void printEnclosed(StringBuilder sb, StackTraceElement[] enclosingTrace, String caption, String prefix, java.util.ArrayList<Throwable> dejaVu) {
        for (Throwable t : dejaVu) if (t == this) { sb.append(prefix).append(caption).append("[CIRCULAR REFERENCE: ").append(this).append("]\n"); return; }
        dejaVu.add(this);
        StackTraceElement[] trace = getOurStackTrace();
        int m = trace.length - 1, n = enclosingTrace.length - 1;
        while (m >= 0 && n >= 0 && trace[m].equals(enclosingTrace[n])) { m--; n--; }
        int framesInCommon = trace.length - 1 - m;
        sb.append(prefix).append(caption).append(this).append('\n');
        for (int i = 0; i <= m; i++) sb.append(prefix).append("\tat ").append(trace[i]).append('\n');
        if (framesInCommon != 0) sb.append(prefix).append("\t... ").append(framesInCommon).append(" more\n");
        for (Throwable se : getSuppressed()) se.printEnclosed(sb, trace, "Suppressed: ", prefix + "\t", dejaVu);
        Throwable ourCause = getCause();
        if (ourCause != null) ourCause.printEnclosed(sb, enclosingTrace, "Caused by: ", prefix, dejaVu);
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
