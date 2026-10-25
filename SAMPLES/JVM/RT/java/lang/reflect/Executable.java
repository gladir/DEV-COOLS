package java.lang.reflect;
import java.lang.annotation.Annotation;
public abstract class Executable extends AccessibleObject implements Member, GenericDeclaration {
    Class<?> clazz;
    int slot;
    String name;
    String desc;
    Class<?>[] ptypes;
    int modifiers;
    private Class<?>[] exTypes;
    private Annotation[] annos;
    private Annotation[][] panStore;
    private TypeVariable<?>[] tparams;
    Executable() {}
    public Class<?> getDeclaringClass() { return clazz; }
    public int slot() { return slot; }
    public abstract String getName();
    public int getModifiers() { return modifiers; }
    public boolean isSynthetic() { return (modifiers & 0x1000) != 0; }
    public boolean isVarArgs() { return (modifiers & 0x80) != 0; }
    public Class<?>[] getParameterTypes() { return ptypes.clone(); }
    public int getParameterCount() { return ptypes.length; }
    byte[] attr(String n) { return VM.memberAttr(clazz, 1, slot, n); }
    String signature() {
        byte[] b = attr("Signature");
        if (b == null) return null;
        return VM.cpUtf8(clazz, ((b[0] & 255) << 8) | (b[1] & 255));
    }
    public Class<?>[] getExceptionTypes() {
        if (exTypes == null) {
            byte[] b = attr("Exceptions");
            if (b == null) exTypes = new Class<?>[0];
            else {
                int n = ((b[0] & 255) << 8) | (b[1] & 255);
                Class<?>[] r = new Class<?>[n];
                for (int i = 0; i < n; i++) {
                    int idx = ((b[2 + 2 * i] & 255) << 8) | (b[3 + 2 * i] & 255);
                    r[i] = VM.classOfName(VM.cpUtf8(clazz, idx));
                }
                exTypes = r;
            }
        }
        return exTypes.clone();
    }
    public TypeVariable<?>[] getTypeParameters() {
        if (tparams == null) {
            String sig = signature();
            tparams = Generics.typeParams(sig, this);
        }
        return tparams.clone();
    }
    public Type[] getGenericParameterTypes() {
        String sig = signature();
        if (sig == null) return getParameterTypes();
        Type[] r = Generics.methodParams(sig, this);
        if (r.length != ptypes.length) return getParameterTypes();
        return r;
    }
    public Type[] getGenericExceptionTypes() {
        String sig = signature();
        if (sig != null) {
            Type[] r = Generics.methodThrows(sig, this);
            if (r != null && r.length > 0) return r;
        }
        return getExceptionTypes();
    }
    public Parameter[] getParameters() {
        int n = ptypes.length;
        Parameter[] r = new Parameter[n];
        byte[] mp = attr("MethodParameters");
        for (int i = 0; i < n; i++) {
            String pn = null; int fl = 0;
            if (mp != null && (mp[0] & 255) == n) {
                int ni = ((mp[1 + 4 * i] & 255) << 8) | (mp[2 + 4 * i] & 255);
                fl = ((mp[3 + 4 * i] & 255) << 8) | (mp[4 + 4 * i] & 255);
                if (ni != 0) pn = VM.cpUtf8(clazz, ni);
            }
            r[i] = new Parameter(pn == null ? "arg" + i : pn, fl, this, i, pn != null);
        }
        return r;
    }
    public Annotation[] getDeclaredAnnotations() {
        if (annos == null) annos = AnnotationSupport.parse(attr("RuntimeVisibleAnnotations"), clazz);
        return annos.clone();
    }
    public Annotation[] getAnnotations() { return getDeclaredAnnotations(); }
    public <T extends Annotation> T getAnnotation(Class<T> annotationClass) {
        if (annotationClass == null) throw new NullPointerException();
        for (Annotation a : getDeclaredAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
    public Annotation[][] getParameterAnnotations() {
        if (panStore == null) {
            panStore = AnnotationSupport.parseParams(attr("RuntimeVisibleParameterAnnotations"), clazz, ptypes.length);
        }
        Annotation[][] r = new Annotation[panStore.length][];
        for (int i = 0; i < r.length; i++) r[i] = panStore[i].clone();
        return r;
    }
    public AnnotatedType[] getAnnotatedParameterTypes() {
        Type[] gt = getGenericParameterTypes();
        AnnotatedType[] r = new AnnotatedType[gt.length];
        for (int i = 0; i < gt.length; i++) r[i] = TypeAnnotations.annotate(gt[i], attr("RuntimeVisibleTypeAnnotations"), clazz, 0x16, i);
        return r;
    }
    public AnnotatedType[] getAnnotatedExceptionTypes() {
        Type[] gt = getGenericExceptionTypes();
        AnnotatedType[] r = new AnnotatedType[gt.length];
        for (int i = 0; i < gt.length; i++) r[i] = TypeAnnotations.annotate(gt[i], attr("RuntimeVisibleTypeAnnotations"), clazz, 0x17, i);
        return r;
    }
    public AnnotatedType getAnnotatedReceiverType() { return null; }
    String paramString(boolean generic) {
        StringBuilder sb = new StringBuilder("(");
        Type[] ts = generic ? getGenericParameterTypes() : ptypes;
        for (int i = 0; i < ts.length; i++) {
            if (i > 0) sb.append(',');
            String s = ts[i].getTypeName();
            if (generic && isVarArgs() && i == ts.length - 1 && s.endsWith("[]")) s = s.substring(0, s.length() - 2) + "...";
            sb.append(s);
        }
        sb.append(')');
        return sb.toString();
    }
    String throwsString(boolean generic) {
        Type[] ex = generic ? getGenericExceptionTypes() : getExceptionTypes();
        if (ex.length == 0) return "";
        StringBuilder sb = new StringBuilder(" throws ");
        for (int i = 0; i < ex.length; i++) {
            if (i > 0) sb.append(',');
            sb.append(ex[i].getTypeName());
        }
        return sb.toString();
    }
    void checkAccess(Object obj) throws IllegalAccessException {
        if (override) return;
        if ((modifiers & (Modifier.PRIVATE | Modifier.PROTECTED)) == 0 && (modifiers & Modifier.PUBLIC) != 0) return;
        Class<?> caller = AnnotationSupport.callerClass(3);
        if (caller == null) return;
        AnnotationSupport.checkMember(caller, clazz, modifiers);
    }
}
