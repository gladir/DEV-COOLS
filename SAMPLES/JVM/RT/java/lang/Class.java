package java.lang;
public final class Class<T> implements java.io.Serializable {
    private Class() {}
    public native String getName();
    public native String getSimpleName();
    public String getTypeName() { return getName(); }
    public String getCanonicalName() { return getName().replace('$', '.'); }
    public native boolean isInstance(Object obj);
    public native boolean isAssignableFrom(Class<?> cls);
    public native boolean isInterface();
    public native boolean isArray();
    public native boolean isPrimitive();
    public native Class<? super T> getSuperclass();
    public native int getModifiers();
    public native Class<?> getComponentType();
    public native boolean isEnum();
    public native boolean isRecord();
    public native boolean isAnonymousClass();
    public native String getPackageName();
    public native T[] getEnumConstants();
    public native boolean desiredAssertionStatus();
    public static native Class<?> forName(String name) throws ClassNotFoundException;
    static native Class<?> getPrimitiveClass(String name);
    public T cast(Object obj) {
        if (obj != null && !isInstance(obj)) throw new ClassCastException("Cannot cast " + obj.getClass().getName() + " to " + getName());
        return (T) obj;
    }
    public T newInstance() throws InstantiationException, IllegalAccessException { return (T) VM.newInstance(this); }
    public String toString() { return (isInterface() ? "interface " : (isPrimitive() ? "" : "class ")) + getName(); }
    public boolean isSealed() { return false; }
    public boolean isAnnotation() { return false; }
    public native boolean isSynthetic();
    public boolean isMemberClass() { return false; }
    public boolean isLocalClass() { return false; }
    public ClassLoader getClassLoader() { return null; }
}
