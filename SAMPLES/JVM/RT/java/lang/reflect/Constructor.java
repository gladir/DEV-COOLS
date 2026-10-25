package java.lang.reflect;
import java.lang.annotation.Annotation;
public final class Constructor<T> extends Executable {
    Constructor(Class<T> clazz, int slot, Class<?>[] ptypes, int modifiers, String desc) {
        this.clazz = clazz; this.slot = slot; this.ptypes = ptypes; this.modifiers = modifiers; this.desc = desc;
    }
    public static <T> Constructor<T> make(Class<T> c, int slot) {
        String d = VM.memberDesc(c, 1, slot);
        return new Constructor<T>(c, slot, VM.paramTypes(d), VM.memberFlags(c, 1, slot), d);
    }
    public Class<T> getDeclaringClass() { return (Class<T>) clazz; }
    public String getName() { return clazz.getName(); }
    public T newInstance(Object... initargs) throws InstantiationException, IllegalAccessException, IllegalArgumentException, InvocationTargetException {
        checkAccess(null);
        if ((clazz.getModifiers() & Modifier.ABSTRACT) != 0 || clazz.isInterface()) throw new InstantiationException();
        if (clazz.isEnum()) throw new IllegalArgumentException("Cannot reflectively create enum objects");
        int n = initargs == null ? 0 : initargs.length;
        if (n != ptypes.length) throw new IllegalArgumentException("wrong number of arguments: " + n + " expected: " + ptypes.length);
        for (int i = 0; i < n; i++) AnnotationSupport.checkArg(ptypes[i], initargs[i]);
        Object r;
        try {
            r = VM.construct0(clazz, slot, initargs);
        } catch (Throwable t) {
            throw new InvocationTargetException(t);
        }
        return (T) r;
    }
    public AnnotatedType getAnnotatedReturnType() {
        return TypeAnnotations.annotate(clazz, attr("RuntimeVisibleTypeAnnotations"), clazz, 0x14, 0);
    }
    public String toString() {
        StringBuilder sb = new StringBuilder();
        int mod = getModifiers() & Modifier.constructorModifiers();
        if (mod != 0) sb.append(Modifier.toString(mod)).append(' ');
        sb.append(clazz.getTypeName());
        sb.append(paramString(false));
        sb.append(throwsString(false));
        return sb.toString();
    }
    public String toGenericString() {
        StringBuilder sb = new StringBuilder();
        int mod = getModifiers() & Modifier.constructorModifiers();
        if (mod != 0) sb.append(Modifier.toString(mod)).append(' ');
        TypeVariable<?>[] tp = getTypeParameters();
        if (tp.length > 0) {
            sb.append('<');
            for (int i = 0; i < tp.length; i++) {
                if (i > 0) sb.append(',');
                sb.append(AnnotationSupport.tvString(tp[i]));
            }
            sb.append("> ");
        }
        sb.append(clazz.getTypeName());
        sb.append(paramString(true));
        sb.append(throwsString(true));
        return sb.toString();
    }
    public boolean equals(Object obj) {
        if (obj instanceof Constructor) {
            Constructor<?> o = (Constructor<?>) obj;
            return clazz == o.clazz && java.util.Arrays.equals(ptypes, o.ptypes);
        }
        return false;
    }
    public int hashCode() { return clazz.getName().hashCode(); }
    public Constructor<T> copy() {
        Constructor<T> c = new Constructor<T>((Class<T>) clazz, slot, ptypes, modifiers, desc);
        c.override = override;
        return c;
    }
}
