package java.lang.reflect;
public class Modifier {
    private Modifier() {}
    public static final int PUBLIC = 0x1, PRIVATE = 0x2, PROTECTED = 0x4, STATIC = 0x8, FINAL = 0x10,
        SYNCHRONIZED = 0x20, VOLATILE = 0x40, TRANSIENT = 0x80, NATIVE = 0x100, INTERFACE = 0x200,
        ABSTRACT = 0x400, STRICT = 0x800;
    static final int BRIDGE = 0x40, VARARGS = 0x80, SYNTHETIC = 0x1000, ANNOTATION = 0x2000, ENUM = 0x4000, MANDATED = 0x8000;
    public static boolean isPublic(int mod) { return (mod & PUBLIC) != 0; }
    public static boolean isPrivate(int mod) { return (mod & PRIVATE) != 0; }
    public static boolean isProtected(int mod) { return (mod & PROTECTED) != 0; }
    public static boolean isStatic(int mod) { return (mod & STATIC) != 0; }
    public static boolean isFinal(int mod) { return (mod & FINAL) != 0; }
    public static boolean isSynchronized(int mod) { return (mod & SYNCHRONIZED) != 0; }
    public static boolean isVolatile(int mod) { return (mod & VOLATILE) != 0; }
    public static boolean isTransient(int mod) { return (mod & TRANSIENT) != 0; }
    public static boolean isNative(int mod) { return (mod & NATIVE) != 0; }
    public static boolean isInterface(int mod) { return (mod & INTERFACE) != 0; }
    public static boolean isAbstract(int mod) { return (mod & ABSTRACT) != 0; }
    public static boolean isStrict(int mod) { return (mod & STRICT) != 0; }
    public static String toString(int mod) {
        StringBuilder sb = new StringBuilder();
        if ((mod & PUBLIC) != 0) sb.append("public ");
        if ((mod & PROTECTED) != 0) sb.append("protected ");
        if ((mod & PRIVATE) != 0) sb.append("private ");
        if ((mod & ABSTRACT) != 0) sb.append("abstract ");
        if ((mod & STATIC) != 0) sb.append("static ");
        if ((mod & FINAL) != 0) sb.append("final ");
        if ((mod & TRANSIENT) != 0) sb.append("transient ");
        if ((mod & VOLATILE) != 0) sb.append("volatile ");
        if ((mod & SYNCHRONIZED) != 0) sb.append("synchronized ");
        if ((mod & NATIVE) != 0) sb.append("native ");
        if ((mod & STRICT) != 0) sb.append("strictfp ");
        if ((mod & INTERFACE) != 0) sb.append("interface ");
        int n = sb.length();
        if (n > 0) return sb.substring(0, n - 1);
        return "";
    }
    public static int classModifiers() { return PUBLIC | PROTECTED | PRIVATE | ABSTRACT | STATIC | FINAL | STRICT; }
    public static int interfaceModifiers() { return PUBLIC | PROTECTED | PRIVATE | ABSTRACT | STATIC | STRICT; }
    public static int constructorModifiers() { return PUBLIC | PROTECTED | PRIVATE; }
    public static int methodModifiers() { return PUBLIC | PROTECTED | PRIVATE | ABSTRACT | STATIC | FINAL | SYNCHRONIZED | NATIVE | STRICT; }
    public static int fieldModifiers() { return PUBLIC | PROTECTED | PRIVATE | STATIC | FINAL | TRANSIENT | VOLATILE; }
    public static int parameterModifiers() { return FINAL; }
}
