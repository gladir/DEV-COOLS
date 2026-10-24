package java.lang;
public class VirtualMachineError extends Error {
    public VirtualMachineError() { super(); }
    public VirtualMachineError(String s) { super(s); }
    public VirtualMachineError(String s, Throwable cause) { super(s, cause); }
    public VirtualMachineError(Throwable cause) { super(cause); }
}
