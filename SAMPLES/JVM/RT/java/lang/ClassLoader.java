package java.lang;
import java.io.InputStream;
public abstract class ClassLoader {
    private final ClassLoader parent;
    private static ClassLoader sys;
    protected ClassLoader() { this(getSystemClassLoader()); }
    protected ClassLoader(ClassLoader parent) { this.parent = parent; }
    protected ClassLoader(String name, ClassLoader parent) { this.parent = parent; }
    public static ClassLoader getSystemClassLoader() {
        if (sys == null) sys = new AppClassLoader();
        return sys;
    }
    public static ClassLoader getPlatformClassLoader() { return getSystemClassLoader(); }
    public String getName() { return null; }
    public final ClassLoader getParent() { return parent; }
    public Class<?> loadClass(String name) throws ClassNotFoundException { return loadClass(name, false); }
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);
        if (c == null) {
            try {
                if (parent != null) c = parent.loadClass(name);
            } catch (ClassNotFoundException e) { }
            if (c == null) c = findClass(name);
        }
        return c;
    }
    protected Class<?> findClass(String name) throws ClassNotFoundException { throw new ClassNotFoundException(name); }
    protected final Class<?> defineClass(String name, byte[] b, int off, int len) throws ClassFormatError {
        if (off < 0 || len < 0 || off + len > b.length) throw new IndexOutOfBoundsException();
        return VM.defineClass0(name, b, off, len);
    }
    protected final Class<?> defineClass(byte[] b, int off, int len) throws ClassFormatError { return defineClass(null, b, off, len); }
    protected final Class<?> defineClass(String name, byte[] b, int off, int len, java.security.ProtectionDomain pd) throws ClassFormatError { return defineClass(name, b, off, len); }
    protected final void resolveClass(Class<?> c) { }
    protected final Class<?> findLoadedClass(String name) { return VM.classOfName(name); }
    protected final Class<?> findSystemClass(String name) throws ClassNotFoundException { return Class.forName(name); }
    public java.net.URL getResource(String name) {
        String u = VM.resourceUrl(name);
        if (u == null) return null;
        try { return new java.net.URL(u); } catch (java.net.MalformedURLException e) { return null; }
    }
    public java.util.Enumeration<java.net.URL> getResources(String name) throws java.io.IOException {
        java.util.Vector<java.net.URL> v = new java.util.Vector<>();
        java.net.URL u = getResource(name);
        if (u != null) v.add(u);
        return v.elements();
    }
    public InputStream getResourceAsStream(String name) {
        byte[] b = VM.resource0(name);
        return b == null ? null : new java.io.ByteArrayInputStream(b);
    }
    public static java.net.URL getSystemResource(String name) { return getSystemClassLoader().getResource(name); }
    public static InputStream getSystemResourceAsStream(String name) { return getSystemClassLoader().getResourceAsStream(name); }
    public static java.util.Enumeration<java.net.URL> getSystemResources(String name) throws java.io.IOException { return getSystemClassLoader().getResources(name); }
    public void setDefaultAssertionStatus(boolean enabled) { }
}
