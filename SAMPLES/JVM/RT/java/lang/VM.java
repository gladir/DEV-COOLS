package java.lang;
public final class VM {
    private VM() {}
    public static native void write(int fd, String s);
    public static native void writeByte(int fd, int b);
    public static native void flush();
    public static native int readByte();
    public static native void sleep(long ms);
    public static native String property(String key);
    public static native String getenv(String key);
    public static native void gc();
    public static native long freeMemory();
    public static native long totalMemory();
    public static native int ncpu();
    public static native String fixed(double d, int prec);
    public static native Object newInstance(Class<?> c);
    public static native Object newArray(Class<?> c, int n);
    public static Runnable pumpHook;
    public static native Class<?> classOfName(String n);
    public static native int memberCount(Class<?> c, int kind);
    public static native String memberName(Class<?> c, int kind, int i);
    public static native String memberDesc(Class<?> c, int kind, int i);
    public static native int memberFlags(Class<?> c, int kind, int i);
    public static native byte[] memberAttr(Class<?> c, int kind, int i, String name);
    public static native String cpUtf8(Class<?> c, int i);
    public static native String cpRef(Class<?> c, int i, int part);
    public static native int cpTag(Class<?> c, int i);
    public static native long cpNum(Class<?> c, int i);
    public static native Object fieldGet(Object o, Class<?> c, int i);
    public static native void fieldSet(Object o, Class<?> c, int i, Object v);
    public static native Object invoke0(Class<?> c, int mi, Object recv, Object[] args);
    public static native Object construct0(Class<?> c, int mi, Object[] args);
    public static native Object allocate(Class<?> c);
    public static native void initClass(Class<?> c);
    public static native byte[] resource0(String name);
    public static native String resourceUrl(String name);
    public static native String[] classpath();
    public static native void addClasspath(String path);
    public static native Class<?> defineClass0(String name, byte[] b, int off, int len);
    public static native Class<?> defineProxy(Class<?>[] ifaces, String name);
    public static Class<?> classOfDesc(String d) {
        switch (d.charAt(0)) {
            case 'B': return byte.class;
            case 'C': return char.class;
            case 'D': return double.class;
            case 'F': return float.class;
            case 'I': return int.class;
            case 'J': return long.class;
            case 'S': return short.class;
            case 'Z': return boolean.class;
            case 'V': return void.class;
            case 'L': return classOfName(d.substring(1, d.length() - 1));
            default: return classOfName(d);
        }
    }
    public static Class<?> classOfDescOrThrow(String d) {
        Class<?> c = classOfDesc(d);
        if (c == null) {
            String n = d.charAt(0) == 'L' ? d.substring(1, d.length() - 1) : d;
            throw new NoClassDefFoundError(n);
        }
        return c;
    }
    public static Class<?>[] paramTypes(String d) {
        java.util.ArrayList<Class<?>> out = new java.util.ArrayList<>();
        int i = 1;
        while (d.charAt(i) != ')') {
            int s = i;
            while (d.charAt(i) == '[') i++;
            if (d.charAt(i) == 'L') i = d.indexOf(';', i);
            i++;
            out.add(classOfDescOrThrow(d.substring(s, i)));
        }
        return out.toArray(new Class<?>[0]);
    }
    public static Class<?> returnType(String d) { return classOfDescOrThrow(d.substring(d.indexOf(')') + 1)); }
}
