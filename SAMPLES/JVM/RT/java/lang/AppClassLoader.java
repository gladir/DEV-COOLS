package java.lang;
final class AppClassLoader extends ClassLoader {
    AppClassLoader() { super((ClassLoader) null); }
    public String getName() { return "app"; }
    public Class<?> loadClass(String name) throws ClassNotFoundException { return Class.forName(name); }
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException { return Class.forName(name); }
    protected Class<?> findClass(String name) throws ClassNotFoundException { return Class.forName(name); }
    public String toString() { return "jdk.internal.loader.ClassLoaders$AppClassLoader@" + Integer.toHexString(hashCode()); }
}
