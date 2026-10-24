package java.lang;
public class InternalError extends VirtualMachineError {
    public InternalError() { super(); }
    public InternalError(String s) { super(s); }
    public InternalError(String s, Throwable cause) { super(s, cause); }
    public InternalError(Throwable cause) { super(cause); }
}
