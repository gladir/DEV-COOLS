package java.lang;
import java.lang.annotation.Annotation;
import java.lang.reflect.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
public final class Class<T> implements java.io.Serializable, GenericDeclaration, Type, AnnotatedElement {
    private static final long serialVersionUID = 3206093459760846163L;
    private Field[] fieldCache;
    private Method[] methodCache;
    private Constructor<T>[] ctorCache;
    private TypeVariable<?>[] tvarCache;
    private Annotation[] annoCache;
    private RecordComponent[] rcCache;
    private Class() {}
    public native String getName();
    public String getSimpleName() { return isArray() ? getComponentType().getSimpleName() + "[]" : simpleName0(); }
    private native String simpleName0();
    public String getTypeName() {
        if (isArray()) {
            Class<?> cl = this;
            int dimensions = 0;
            while (cl.isArray()) { dimensions++; cl = cl.getComponentType(); }
            StringBuilder sb = new StringBuilder();
            sb.append(cl.getName());
            for (int i = 0; i < dimensions; i++) sb.append("[]");
            return sb.toString();
        }
        return getName();
    }
    public String getCanonicalName() {
        if (isArray()) {
            String c = getComponentType().getCanonicalName();
            return c == null ? null : c + "[]";
        }
        if (isAnonymousClass() || isLocalClass()) return null;
        Class<?> d = getDeclaringClass();
        if (d == null) return getName();
        String c = d.getCanonicalName();
        return c == null ? null : c + "." + getSimpleName();
    }
    public native boolean isInstance(Object obj);
    public native boolean isAssignableFrom(Class<?> cls);
    public native boolean isInterface();
    public native boolean isArray();
    public native boolean isPrimitive();
    public native Class<? super T> getSuperclass();
    public native int getModifiers();
    public native Class<?> getComponentType();
    public Class<?> componentType() { return getComponentType(); }
    public Class<?> arrayType() { return Array.newInstance(this, 0).getClass(); }
    public native boolean isEnum();
    public native boolean isRecord();
    public native boolean isAnonymousClass();
    public native String getPackageName();
    public Package getPackage() { return isPrimitive() || isArray() ? null : new Package(getPackageName()); }
    public native T[] getEnumConstants();
    public native boolean desiredAssertionStatus();
    public static native Class<?> forName(String name) throws ClassNotFoundException;
    public static Class<?> forName(String name, boolean initialize, ClassLoader loader) throws ClassNotFoundException { return forName(name); }
    static native Class<?> getPrimitiveClass(String name);
    public T cast(Object obj) {
        if (obj != null && !isInstance(obj)) throw new ClassCastException("Cannot cast " + obj.getClass().getName() + " to " + getName());
        return (T) obj;
    }
    public <U> Class<? extends U> asSubclass(Class<U> clazz) {
        if (clazz.isAssignableFrom(this)) return (Class<? extends U>) this;
        throw new ClassCastException(this.toString());
    }
    public T newInstance() throws InstantiationException, IllegalAccessException {
        try {
            return getDeclaredConstructor().newInstance();
        } catch (NoSuchMethodException e) {
            throw new InstantiationException(getName());
        } catch (InvocationTargetException e) {
            Throwable t = e.getCause();
            if (t instanceof RuntimeException) throw (RuntimeException) t;
            if (t instanceof Error) throw (Error) t;
            throw new RuntimeException(t);
        }
    }
    public String toString() { return (isInterface() ? "interface " : (isPrimitive() ? "" : "class ")) + getName(); }
    public String toGenericString() {
        if (isPrimitive()) return toString();
        StringBuilder sb = new StringBuilder();
        int modifiers = getModifiers() & Modifier.classModifiers();
        if (modifiers != 0) { sb.append(Modifier.toString(modifiers)); sb.append(' '); }
        if (isAnnotation()) sb.append('@');
        if (isInterface()) sb.append("interface");
        else if (isEnum()) sb.append("enum");
        else if (isRecord()) sb.append("record");
        else sb.append("class");
        sb.append(' ');
        sb.append(getName());
        TypeVariable<?>[] typeparms = getTypeParameters();
        if (typeparms.length > 0) {
            sb.append('<');
            for (int i = 0; i < typeparms.length; i++) { if (i > 0) sb.append(','); sb.append(AnnotationSupport.tvString(typeparms[i])); }
            sb.append('>');
        }
        return sb.toString();
    }
    public String descriptorString() {
        if (isPrimitive()) {
            String n = getName();
            if (n.equals("int")) return "I";
            if (n.equals("long")) return "J";
            if (n.equals("boolean")) return "Z";
            if (n.equals("byte")) return "B";
            if (n.equals("short")) return "S";
            if (n.equals("char")) return "C";
            if (n.equals("float")) return "F";
            if (n.equals("double")) return "D";
            return "V";
        }
        if (isArray()) return getName().replace('.', '/');
        return "L" + getName().replace('.', '/') + ";";
    }
    public native Class<?>[] getInterfaces();
    native Class<?>[] permitted0();
    public boolean isSealed() { return permitted0().length > 0; }
    public Class<?>[] getPermittedSubclasses() { Class<?>[] r = permitted0(); return r.length == 0 ? null : r; }
    public boolean isAnnotation() { return (getModifiers() & 0x2000) != 0; }
    public native boolean isSynthetic();
    public boolean isHidden() { return false; }
    public ClassLoader getClassLoader() { return null; }

    // ----- classes imbriquees ------------------------------------------------
    private int[] innerEntry() {
        byte[] b = VM.memberAttr(this, 2, 0, "InnerClasses");
        if (b == null) return null;
        int n = ((b[0] & 255) << 8) | (b[1] & 255);
        String me = getName().replace('.', '/');
        for (int i = 0; i < n; i++) {
            int o = 2 + 8 * i;
            int inner = ((b[o] & 255) << 8) | (b[o + 1] & 255);
            if (VM.cpUtf8(this, inner).equals(me)) {
                return new int[]{((b[o + 2] & 255) << 8) | (b[o + 3] & 255), ((b[o + 4] & 255) << 8) | (b[o + 5] & 255), ((b[o + 6] & 255) << 8) | (b[o + 7] & 255)};
            }
        }
        return null;
    }
    private int[] enclosingMethodAttr() {
        byte[] b = VM.memberAttr(this, 2, 0, "EnclosingMethod");
        if (b == null) return null;
        return new int[]{((b[0] & 255) << 8) | (b[1] & 255), ((b[2] & 255) << 8) | (b[3] & 255)};
    }
    public Class<?> getDeclaringClass() {
        int[] e = innerEntry();
        if (e == null || e[0] == 0) return null;
        return VM.classOfName(VM.cpUtf8(this, e[0]));
    }
    public Class<?> getEnclosingClass() {
        Class<?> d = getDeclaringClass();
        if (d != null) return d;
        int[] em = enclosingMethodAttr();
        if (em != null) return VM.classOfName(VM.cpUtf8(this, em[0]));
        return null;
    }
    public boolean isMemberClass() { int[] e = innerEntry(); return e != null && e[0] != 0; }
    public boolean isLocalClass() { return enclosingMethodAttr() != null && !isAnonymousClass(); }
    public Class<?> getNestHost() {
        Class<?> c = this;
        while (c.getEnclosingClass() != null) c = c.getEnclosingClass();
        return c;
    }
    public Class<?>[] getDeclaredClasses() {
        byte[] b = VM.memberAttr(this, 2, 0, "InnerClasses");
        ArrayList<Class<?>> out = new ArrayList<>();
        if (b != null) {
            int n = ((b[0] & 255) << 8) | (b[1] & 255);
            String me = getName().replace('.', '/');
            for (int i = 0; i < n; i++) {
                int o = 2 + 8 * i;
                int outer = ((b[o + 2] & 255) << 8) | (b[o + 3] & 255);
                if (outer != 0 && VM.cpUtf8(this, outer).equals(me)) {
                    int inner = ((b[o] & 255) << 8) | (b[o + 1] & 255);
                    Class<?> c = VM.classOfName(VM.cpUtf8(this, inner));
                    if (c != null) out.add(c);
                }
            }
        }
        return out.toArray(new Class<?>[0]);
    }
    public Class<?>[] getClasses() {
        ArrayList<Class<?>> out = new ArrayList<>();
        for (Class<?> c = this; c != null; c = c.getSuperclass())
            for (Class<?> d : c.getDeclaredClasses()) if (Modifier.isPublic(d.getModifiers())) out.add(d);
        return out.toArray(new Class<?>[0]);
    }
    public Executable enclosingExecutable() {
        int[] em = enclosingMethodAttr();
        if (em == null || em[1] == 0) return null;
        Class<?> ec = VM.classOfName(VM.cpUtf8(this, em[0]));
        if (ec == null) return null;
        String name = VM.cpRef(this, em[1], 0), desc = VM.cpRef(this, em[1], 1);
        int n = VM.memberCount(ec, 1);
        for (int i = 0; i < n; i++) {
            if (VM.memberName(ec, 1, i).equals(name) && VM.memberDesc(ec, 1, i).equals(desc)) {
                if (name.equals("<init>")) return Constructor.make((Class<Object>) ec, i);
                return Method.make(ec, i);
            }
        }
        return null;
    }
    public Method getEnclosingMethod() { Executable e = enclosingExecutable(); return e instanceof Method ? (Method) e : null; }
    public Constructor<?> getEnclosingConstructor() { Executable e = enclosingExecutable(); return e instanceof Constructor ? (Constructor<?>) e : null; }

    // ----- membres -------------------------------------------------------------
    private Field[] declFields() {
        if (fieldCache == null) {
            int n = VM.memberCount(this, 0);
            Field[] r = new Field[n];
            for (int i = 0; i < n; i++) r[i] = Field.make(this, i);
            fieldCache = r;
        }
        return fieldCache;
    }
    private Method[] declMethods() {
        if (methodCache == null) {
            int n = VM.memberCount(this, 1);
            ArrayList<Method> r = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                if (VM.memberFlags(this, 1, i) == -1) continue;
                String nm = VM.memberName(this, 1, i);
                if (nm.equals("<init>") || nm.equals("<clinit>")) continue;
                r.add(Method.make(this, i));
            }
            methodCache = r.toArray(new Method[0]);
        }
        return methodCache;
    }
    private Constructor<T>[] declCtors() {
        if (ctorCache == null) {
            int n = VM.memberCount(this, 1);
            ArrayList<Constructor<T>> r = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                if (VM.memberFlags(this, 1, i) == -1) continue;
                if (VM.memberName(this, 1, i).equals("<init>")) r.add(Constructor.make((Class<T>) this, i));
            }
            ctorCache = (Constructor<T>[]) r.toArray(new Constructor<?>[0]);
        }
        return ctorCache;
    }
    public Field[] getDeclaredFields() {
        Field[] f = declFields();
        Field[] r = new Field[f.length];
        for (int i = 0; i < f.length; i++) r[i] = f[i].copy();
        return r;
    }
    public Method[] getDeclaredMethods() {
        Method[] m = declMethods();
        Method[] r = new Method[m.length];
        for (int i = 0; i < m.length; i++) r[i] = m[i].copy();
        return r;
    }
    public Constructor<?>[] getDeclaredConstructors() {
        Constructor<T>[] c = declCtors();
        Constructor<?>[] r = new Constructor<?>[c.length];
        for (int i = 0; i < c.length; i++) r[i] = c[i].copy();
        return r;
    }
    public Constructor<?>[] getConstructors() {
        ArrayList<Constructor<?>> out = new ArrayList<>();
        for (Constructor<T> c : declCtors()) if (Modifier.isPublic(c.getModifiers())) out.add(c.copy());
        return out.toArray(new Constructor<?>[0]);
    }
    private void collectFields(ArrayList<Field> out) {
        for (Field f : declFields()) if (Modifier.isPublic(f.getModifiers())) out.add(f.copy());
        for (Class<?> i : getInterfaces()) i.collectFields(out);
        Class<?> s = getSuperclass();
        if (s != null) s.collectFields(out);
    }
    public Field[] getFields() {
        ArrayList<Field> out = new ArrayList<>();
        collectFields(out);
        return out.toArray(new Field[0]);
    }
    private Field findPublicField(String name) {
        for (Field f : declFields()) if (f.getName().equals(name) && Modifier.isPublic(f.getModifiers())) return f;
        for (Class<?> i : getInterfaces()) { Field f = i.findPublicField(name); if (f != null) return f; }
        Class<?> s = getSuperclass();
        return s == null ? null : s.findPublicField(name);
    }
    public Field getField(String name) throws NoSuchFieldException {
        if (name == null) throw new NullPointerException();
        Field f = findPublicField(name);
        if (f == null) throw new NoSuchFieldException(name);
        return f.copy();
    }
    public Field getDeclaredField(String name) throws NoSuchFieldException {
        if (name == null) throw new NullPointerException();
        for (Field f : declFields()) if (f.getName().equals(name)) return f.copy();
        throw new NoSuchFieldException(name);
    }
    private static String sigKey(Method m) {
        StringBuilder sb = new StringBuilder(m.getName());
        for (Class<?> p : m.getParameterTypes()) sb.append(',').append(p.getName());
        return sb.toString();
    }
    private void collectMethods(LinkedHashMap<String, Method> map, boolean statics) {
        for (Method m : declMethods()) {
            if (!Modifier.isPublic(m.getModifiers())) continue;
            if (!statics && Modifier.isStatic(m.getModifiers())) continue;
            String k = sigKey(m) + ")" + m.getReturnType().getName();
            if (!map.containsKey(k)) map.put(k, m.copy());
        }
        Class<?> s = getSuperclass();
        if (s != null) s.collectMethods(map, true);
        for (Class<?> i : getInterfaces()) i.collectMethods(map, false);
    }
    public Method[] getMethods() {
        LinkedHashMap<String, Method> map = new LinkedHashMap<>();
        collectMethods(map, true);
        return map.values().toArray(new Method[0]);
    }
    private static String argString(Class<?>[] ps) {
        StringBuilder sb = new StringBuilder("(");
        if (ps != null) for (int i = 0; i < ps.length; i++) { if (i > 0) sb.append(','); sb.append(ps[i] == null ? "null" : ps[i].getName()); }
        return sb.append(')').toString();
    }
    private Method findPublicMethod(String name, Class<?>[] ps, boolean statics) {
        Method best = null;
        for (Method m : declMethods()) {
            if (!m.getName().equals(name) || !Arrays.equals(m.getParameterTypes(), ps) || !Modifier.isPublic(m.getModifiers())) continue;
            if (!statics && Modifier.isStatic(m.getModifiers())) continue;
            if (best == null || best.getReturnType().isAssignableFrom(m.getReturnType()) && best.getReturnType() != m.getReturnType()) best = m;
        }
        if (best != null) return best;
        Class<?> s = getSuperclass();
        if (s != null) { Method m = s.findPublicMethod(name, ps, true); if (m != null) return m; }
        for (Class<?> i : getInterfaces()) { Method m = i.findPublicMethod(name, ps, false); if (m != null) return m; }
        return null;
    }
    public Method getMethod(String name, Class<?>... parameterTypes) throws NoSuchMethodException {
        if (name == null) throw new NullPointerException();
        Class<?>[] ps = parameterTypes == null ? new Class<?>[0] : parameterTypes;
        Method m = findPublicMethod(name, ps, true);
        if (m == null) throw new NoSuchMethodException(getName() + "." + name + argString(ps));
        return m.copy();
    }
    public Method getDeclaredMethod(String name, Class<?>... parameterTypes) throws NoSuchMethodException {
        if (name == null) throw new NullPointerException();
        Class<?>[] ps = parameterTypes == null ? new Class<?>[0] : parameterTypes;
        Method best = null;
        for (Method m : declMethods()) {
            if (!m.getName().equals(name) || !Arrays.equals(m.getParameterTypes(), ps)) continue;
            if (best == null || best.getReturnType().isAssignableFrom(m.getReturnType()) && best.getReturnType() != m.getReturnType()) best = m;
        }
        if (best == null) throw new NoSuchMethodException(getName() + "." + name + argString(ps));
        return best.copy();
    }
    public Constructor<T> getConstructor(Class<?>... parameterTypes) throws NoSuchMethodException {
        Class<?>[] ps = parameterTypes == null ? new Class<?>[0] : parameterTypes;
        for (Constructor<T> c : declCtors())
            if (Modifier.isPublic(c.getModifiers()) && Arrays.equals(c.getParameterTypes(), ps)) return c.copy();
        throw new NoSuchMethodException(getName() + ".<init>" + argString(ps));
    }
    public Constructor<T> getDeclaredConstructor(Class<?>... parameterTypes) throws NoSuchMethodException {
        Class<?>[] ps = parameterTypes == null ? new Class<?>[0] : parameterTypes;
        for (Constructor<T> c : declCtors())
            if (Arrays.equals(c.getParameterTypes(), ps)) return c.copy();
        throw new NoSuchMethodException(getName() + ".<init>" + argString(ps));
    }
    public RecordComponent[] getRecordComponents() {
        if (!isRecord()) return null;
        if (rcCache == null) {
            byte[] b = VM.memberAttr(this, 2, 0, "Record");
            if (b == null) { rcCache = new RecordComponent[0]; }
            else {
                int[] p = {0};
                int n = u2(b, p);
                RecordComponent[] r = new RecordComponent[n];
                for (int i = 0; i < n; i++) {
                    String name = VM.cpUtf8(this, u2(b, p));
                    String desc = VM.cpUtf8(this, u2(b, p));
                    int na = u2(b, p);
                    String sig = null; byte[] ann = null, tann = null;
                    for (int k = 0; k < na; k++) {
                        String an = VM.cpUtf8(this, u2(b, p));
                        int len = (u2(b, p) << 16) | u2(b, p);
                        byte[] data = Arrays.copyOfRange(b, p[0], p[0] + len);
                        p[0] += len;
                        if (an.equals("Signature")) sig = VM.cpUtf8(this, ((data[0] & 255) << 8) | (data[1] & 255));
                        else if (an.equals("RuntimeVisibleAnnotations")) ann = data;
                        else if (an.equals("RuntimeVisibleTypeAnnotations")) tann = data;
                    }
                    r[i] = RecordComponent.make(this, name, VM.classOfDescOrThrow(desc), sig, ann, tann);
                }
                rcCache = r;
            }
        }
        return rcCache.clone();
    }
    private static int u2(byte[] b, int[] p) { int v = ((b[p[0]] & 255) << 8) | (b[p[0] + 1] & 255); p[0] += 2; return v; }

    // ----- generiques ------------------------------------------------------------
    private String sig() {
        byte[] b = VM.memberAttr(this, 2, 0, "Signature");
        if (b == null) return null;
        return VM.cpUtf8(this, ((b[0] & 255) << 8) | (b[1] & 255));
    }
    public TypeVariable<Class<T>>[] getTypeParameters() {
        if (tvarCache == null) tvarCache = Generics.typeParams(sig(), this);
        return (TypeVariable<Class<T>>[]) tvarCache.clone();
    }
    public Type getGenericSuperclass() {
        String s = sig();
        if (s == null) return getSuperclass();
        if (isInterface()) return null;
        return Generics.classTypes(s, this)[0];
    }
    public Type[] getGenericInterfaces() {
        String s = sig();
        if (s == null) return getInterfaces();
        Type[] all = Generics.classTypes(s, this);
        return Arrays.copyOfRange(all, 1, all.length);
    }

    // ----- annotations -----------------------------------------------------------
    public Annotation[] getDeclaredAnnotations() {
        if (annoCache == null) annoCache = AnnotationSupport.parse(VM.memberAttr(this, 2, 0, "RuntimeVisibleAnnotations"), this);
        return annoCache.clone();
    }
    public Annotation[] getAnnotations() {
        Annotation[] own = getDeclaredAnnotations();
        Class<?> s = getSuperclass();
        if (s == null || isInterface()) return own;
        ArrayList<Annotation> out = new ArrayList<>(Arrays.asList(own));
        for (Annotation a : s.getAnnotations()) {
            if (!a.annotationType().isAnnotationPresent(java.lang.annotation.Inherited.class)) continue;
            boolean have = false;
            for (Annotation o : own) if (o.annotationType() == a.annotationType()) have = true;
            if (!have) out.add(a);
        }
        return out.toArray(new Annotation[0]);
    }
    public <A extends Annotation> A getAnnotation(Class<A> annotationClass) {
        if (annotationClass == null) throw new NullPointerException();
        for (Annotation a : getAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
    public boolean isAnnotationPresent(Class<? extends Annotation> annotationClass) { return getAnnotation(annotationClass) != null; }
    public <A extends Annotation> A getDeclaredAnnotation(Class<A> annotationClass) {
        for (Annotation a : getDeclaredAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
}
