package java.lang.invoke;
import java.io.Serializable;
import java.lang.reflect.Method;
public final class SerializedLambda implements Serializable {
    private static final long serialVersionUID = 8025925345765570181L;
    private final Class<?> capturingClass;
    private final String functionalInterfaceClass;
    private final String functionalInterfaceMethodName;
    private final String functionalInterfaceMethodSignature;
    private final String implClass;
    private final String implMethodName;
    private final String implMethodSignature;
    private final int implMethodKind;
    private final String instantiatedMethodType;
    private final Object[] capturedArgs;
    public SerializedLambda(Class<?> capturingClass, String functionalInterfaceClass, String functionalInterfaceMethodName,
                            String functionalInterfaceMethodSignature, int implMethodKind, String implClass, String implMethodName,
                            String implMethodSignature, String instantiatedMethodType, Object[] capturedArgs) {
        this.capturingClass = capturingClass;
        this.functionalInterfaceClass = functionalInterfaceClass;
        this.functionalInterfaceMethodName = functionalInterfaceMethodName;
        this.functionalInterfaceMethodSignature = functionalInterfaceMethodSignature;
        this.implMethodKind = implMethodKind;
        this.implClass = implClass;
        this.implMethodName = implMethodName;
        this.implMethodSignature = implMethodSignature;
        this.instantiatedMethodType = instantiatedMethodType;
        this.capturedArgs = capturedArgs.clone();
    }
    public static SerializedLambda make(Class<?> c, String fic, String fim, String fis, int kind, String ic, String im, String is, String it, Object[] args) {
        return new SerializedLambda(c, fic, fim, fis, kind, ic, im, is, it, args);
    }
    public String getCapturingClass() { return capturingClass.getName().replace('.', '/'); }
    public String getFunctionalInterfaceClass() { return functionalInterfaceClass; }
    public String getFunctionalInterfaceMethodName() { return functionalInterfaceMethodName; }
    public String getFunctionalInterfaceMethodSignature() { return functionalInterfaceMethodSignature; }
    public String getImplClass() { return implClass; }
    public String getImplMethodName() { return implMethodName; }
    public String getImplMethodSignature() { return implMethodSignature; }
    public int getImplMethodKind() { return implMethodKind; }
    public final String getInstantiatedMethodType() { return instantiatedMethodType; }
    public int getCapturedArgCount() { return capturedArgs.length; }
    public Object getCapturedArg(int i) { return capturedArgs[i]; }
    private Object readResolve() throws java.io.ObjectStreamException {
        try {
            Method deserialize = capturingClass.getDeclaredMethod("$deserializeLambda$", SerializedLambda.class);
            deserialize.setAccessible(true);
            return deserialize.invoke(null, this);
        } catch (java.lang.reflect.InvocationTargetException ite) {
            Throwable cause = ite.getCause();
            if (cause instanceof RuntimeException) throw (RuntimeException) cause;
            if (cause instanceof Error) throw (Error) cause;
            throw new RuntimeException(cause);
        } catch (ReflectiveOperationException roe) {
            throw (java.io.ObjectStreamException) new java.io.InvalidObjectException("ReflectiveOperationException during deserialization").initCause(roe);
        }
    }
}
