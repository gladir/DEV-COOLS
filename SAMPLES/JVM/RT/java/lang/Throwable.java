package java.lang;
import java.io.PrintStream;
import java.io.PrintWriter;
public class Throwable implements java.io.Serializable {
    private static final long serialVersionUID = -3042686055658047285L;
    private transient Object backtrace;
    private String detailMessage;
    private Throwable cause = this;
    private static final StackTraceElement[] UNASSIGNED_STACK = new StackTraceElement[0];
    private static final java.util.List<Throwable> SUPPRESSED_SENTINEL = java.util.Collections.emptyList();
    private StackTraceElement[] stackTrace = UNASSIGNED_STACK;
    private java.util.List<Throwable> suppressedExceptions = SUPPRESSED_SENTINEL;
    private synchronized void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        getOurStackTrace();
        StackTraceElement[] oldStackTrace = stackTrace;
        try {
            if (stackTrace == null) stackTrace = UNASSIGNED_STACK;
            s.defaultWriteObject();
        } finally { stackTrace = oldStackTrace; }
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        if (suppressedExceptions != null) {
            java.util.List<Throwable> suppressed;
            if (suppressedExceptions.isEmpty()) suppressed = SUPPRESSED_SENTINEL;
            else {
                suppressed = new java.util.ArrayList<>(Math.min(suppressedExceptions.size(), 1));
                for (Throwable t : suppressedExceptions) {
                    if (t == null) throw new NullPointerException("Cannot suppress a null exception.");
                    if (t == this) throw new IllegalArgumentException("Self-suppression not permitted", t);
                    suppressed.add(t);
                }
            }
            suppressedExceptions = suppressed;
        }
        if (stackTrace == null) stackTrace = UNASSIGNED_STACK;
    }
    public Throwable() { fillInStackTrace(); }
    public Throwable(String message) { fillInStackTrace(); detailMessage = message; }
    public Throwable(String message, Throwable cause) { fillInStackTrace(); detailMessage = message; this.cause = cause; }
    public Throwable(Throwable cause) { fillInStackTrace(); detailMessage = (cause == null ? null : cause.toString()); this.cause = cause; }
    protected Throwable(String message, Throwable cause, boolean enableSuppression, boolean writableStackTrace) {
        if (writableStackTrace) fillInStackTrace(); else stackTrace = null;
        detailMessage = message; this.cause = cause;
        if (!enableSuppression) suppressedExceptions = null;
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
        if (stackTrace == UNASSIGNED_STACK || (stackTrace == null && backtrace != null)) {
            if (backtrace != null) stackTrace = elements(backtrace);
            else if (stackTrace == null) stackTrace = UNASSIGNED_STACK;
        }
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
        if (suppressedExceptions == null) return;
        if (suppressedExceptions == SUPPRESSED_SENTINEL) suppressedExceptions = new java.util.ArrayList<>(1);
        suppressedExceptions.add(exception);
    }
    public final synchronized Throwable[] getSuppressed() {
        if (suppressedExceptions == SUPPRESSED_SENTINEL || suppressedExceptions == null) return new Throwable[0];
        return suppressedExceptions.toArray(new Throwable[0]);
    }
}
