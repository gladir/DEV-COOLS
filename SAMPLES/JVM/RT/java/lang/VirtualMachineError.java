package java.lang;
public class VirtualMachineError extends Error {
    private static final long serialVersionUID = 4161983926571568670L;
    public VirtualMachineError() { super(); }
    public VirtualMachineError(String s) { super(s); }
    public VirtualMachineError(String s, Throwable cause) { super(s, cause); }
    public VirtualMachineError(Throwable cause) { super(cause); }
}
