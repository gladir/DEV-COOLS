package java.lang.reflect;
import java.lang.annotation.Annotation;
public final class Method extends Executable {
    Class<?> rtype;
    private Object defaultValue;
    private boolean defaultRead;
    Method(Class<?> clazz, int slot, String name, Class<?>[] ptypes, Class<?> rtype, int modifiers, String desc) {
        this.clazz = clazz; this.slot = slot; this.name = name; this.ptypes = ptypes; this.rtype = rtype; this.modifiers = modifiers; this.desc = desc;
    }
    public static Method make(Class<?> c, int slot) {
        String d = VM.memberDesc(c, 1, slot);
        return new Method(c, slot, VM.memberName(c, 1, slot), VM.paramTypes(d), VM.returnType(d), VM.memberFlags(c, 1, slot), d);
    }
    public String getName() { return name; }
    public Class<?> getReturnType() { return rtype; }
    public boolean isBridge() { return (modifiers & 0x40) != 0; }
    public boolean isDefault() {
        return ((modifiers & (Modifier.ABSTRACT | Modifier.PUBLIC | Modifier.STATIC)) == Modifier.PUBLIC) && clazz.isInterface();
    }
    public Type getGenericReturnType() {
        String sig = signature();
        if (sig == null) return rtype;
        return Generics.methodReturn(sig, this);
    }
    public AnnotatedType getAnnotatedReturnType() {
        return TypeAnnotations.annotate(getGenericReturnType(), attr("RuntimeVisibleTypeAnnotations"), clazz, 0x14, 0);
    }
    public Object getDefaultValue() {
        if (!defaultRead) {
            byte[] b = attr("AnnotationDefault");
            if (b != null) defaultValue = AnnotationSupport.parseValue(b, clazz, rtype);
            defaultRead = true;
        }
        return defaultValue;
    }
    public Object invoke(Object obj, Object... args) throws IllegalAccessException, InvocationTargetException {
        checkAccess(obj);
        if ((modifiers & Modifier.STATIC) == 0) {
            if (obj == null) throw new NullPointerException("Cannot invoke \"Object.getClass()\" because \"obj\" is null");
            if (!clazz.isInstance(obj)) throw new IllegalArgumentException("object is not an instance of declaring class");
        }
        int n = args == null ? 0 : args.length;
        if (n != ptypes.length) throw new IllegalArgumentException("wrong number of arguments: " + n + " expected: " + ptypes.length);
        for (int i = 0; i < n; i++) AnnotationSupport.checkArg(ptypes[i], args[i]);
        Object r;
        try {
            r = VM.invoke0(clazz, slot, obj, args);
        } catch (Throwable t) {
            throw new InvocationTargetException(t);
        }
        return r;
    }
    public String toString() {
        StringBuilder sb = new StringBuilder();
        int mod = getModifiers() & Modifier.methodModifiers();
        if (mod != 0 && !isDefault()) sb.append(Modifier.toString(mod)).append(' ');
        else if (isDefault()) { if (mod != 0) sb.append(Modifier.toString(mod & ~Modifier.PUBLIC)).append(' '); sb.append("default "); }
        sb.append(rtype.getTypeName()).append(' ');
        sb.append(clazz.getTypeName()).append('.').append(name);
        sb.append(paramString(false));
        sb.append(throwsString(false));
        return sb.toString();
    }
    public String toGenericString() {
        StringBuilder sb = new StringBuilder();
        int mod = getModifiers() & Modifier.methodModifiers();
        if (mod != 0 && !isDefault()) sb.append(Modifier.toString(mod)).append(' ');
        else if (isDefault()) { if (mod != 0) sb.append(Modifier.toString(mod & ~Modifier.PUBLIC)).append(' '); sb.append("default "); }
        TypeVariable<?>[] tp = getTypeParameters();
        if (tp.length > 0) {
            sb.append('<');
            for (int i = 0; i < tp.length; i++) {
                if (i > 0) sb.append(',');
                sb.append(AnnotationSupport.tvString(tp[i]));
            }
            sb.append("> ");
        }
        sb.append(getGenericReturnType().getTypeName()).append(' ');
        sb.append(clazz.getTypeName()).append('.').append(name);
        sb.append(paramString(true));
        sb.append(throwsString(true));
        return sb.toString();
    }
    public boolean equals(Object obj) {
        if (obj instanceof Method) {
            Method o = (Method) obj;
            return clazz == o.clazz && name.equals(o.name) && rtype == o.rtype && java.util.Arrays.equals(ptypes, o.ptypes);
        }
        return false;
    }
    public int hashCode() { return clazz.getName().hashCode() ^ name.hashCode(); }
    public Method copy() {
        Method m = new Method(clazz, slot, name, ptypes, rtype, modifiers, desc);
        m.override = override;
        return m;
    }
}
