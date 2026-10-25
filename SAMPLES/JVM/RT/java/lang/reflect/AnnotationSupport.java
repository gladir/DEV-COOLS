package java.lang.reflect;
import java.lang.annotation.Annotation;
import java.lang.annotation.Repeatable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
public final class AnnotationSupport {
    private AnnotationSupport() {}

    private static final class Rd {
        final byte[] b; int p;
        Rd(byte[] b) { this.b = b; }
        int u1() { return b[p++] & 255; }
        int u2() { int v = ((b[p] & 255) << 8) | (b[p + 1] & 255); p += 2; return v; }
    }

    public static Annotation[] parse(byte[] attr, Class<?> owner) {
        if (attr == null) return new Annotation[0];
        Rd r = new Rd(attr);
        int n = r.u2();
        ArrayList<Annotation> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            Annotation a = parseAnnotation(r, owner);
            if (a != null) out.add(a);
        }
        return out.toArray(new Annotation[0]);
    }

    public static Annotation[][] parseParams(byte[] attr, Class<?> owner, int nparams) {
        Annotation[][] res = new Annotation[nparams][];
        for (int i = 0; i < nparams; i++) res[i] = new Annotation[0];
        if (attr == null) return res;
        Rd r = new Rd(attr);
        int np = r.u1();
        int off = nparams - np;
        for (int i = 0; i < np; i++) {
            int n = r.u2();
            ArrayList<Annotation> out = new ArrayList<>();
            for (int k = 0; k < n; k++) {
                Annotation a = parseAnnotation(r, owner);
                if (a != null) out.add(a);
            }
            if (i + off >= 0 && i + off < nparams) res[i + off] = out.toArray(new Annotation[0]);
        }
        return res;
    }

    static Annotation[] parseOne(byte[] b, Class<?> owner, int[] used) {
        Rd r = new Rd(b);
        r.u2();
        Annotation a = parseAnnotation(r, owner);
        used[0] = r.p - 2;
        return a == null ? new Annotation[0] : new Annotation[]{a};
    }

    public static Object parseValue(byte[] attr, Class<?> owner, Class<?> expected) {
        return value(new Rd(attr), owner, expected);
    }

    private static final HashMap<Class<?>, HashMap<String, Object>> defaultsCache = new HashMap<>();
    private static final HashMap<Class<?>, HashMap<String, Class<?>>> typesCache = new HashMap<>();

    private static HashMap<String, Object> defaults(Class<?> t) {
        synchronized (defaultsCache) {
            HashMap<String, Object> d = defaultsCache.get(t);
            if (d != null) return d;
            d = new HashMap<>(0);
            HashMap<String, Class<?>> types = new HashMap<>();
            defaultsCache.put(t, d);
            typesCache.put(t, types);
            for (Method m : t.getDeclaredMethods()) {
                if (Modifier.isStatic(m.getModifiers()) || m.getParameterCount() != 0) continue;
                types.put(m.getName(), m.getReturnType());
                Object v = m.getDefaultValue();
                if (v != null) d.put(m.getName(), v);
            }
            return d;
        }
    }

    private static Annotation parseAnnotation(Rd r, Class<?> owner) {
        String desc = VM.cpUtf8(owner, r.u2());
        Class<?> t = VM.classOfDesc(desc);
        int np = r.u2();
        if (t == null || !t.isAnnotation()) {
            for (int i = 0; i < np; i++) { r.u2(); skipValue(r); }
            return null;
        }
        HashMap<String, Object> defs = defaults(t);
        HashMap<String, Class<?>> types = typesCache.get(t);
        LinkedHashMap<String, Object> values = new LinkedHashMap<>(defs);
        for (int i = 0; i < np; i++) {
            String name = VM.cpUtf8(owner, r.u2());
            Object v = value(r, owner, types.get(name));
            if (v != null) values.put(name, v);
        }
        return (Annotation) Proxy.newProxyInstance(null, new Class<?>[]{t}, new AnnotationHandler(t, values));
    }

    private static void skipValue(Rd r) {
        int tag = r.u1();
        switch (tag) {
            case 'e': r.u2(); r.u2(); break;
            case '@': { r.u2(); int n = r.u2(); for (int i = 0; i < n; i++) { r.u2(); skipValue(r); } break; }
            case '[': { int n = r.u2(); for (int i = 0; i < n; i++) skipValue(r); break; }
            default: r.u2();
        }
    }

    private static Object value(Rd r, Class<?> owner, Class<?> expected) {
        int tag = r.u1();
        switch (tag) {
            case 'B': return Byte.valueOf((byte) VM.cpNum(owner, r.u2()));
            case 'C': return Character.valueOf((char) VM.cpNum(owner, r.u2()));
            case 'D': return Double.valueOf(Double.longBitsToDouble(VM.cpNum(owner, r.u2())));
            case 'F': return Float.valueOf(Float.intBitsToFloat((int) VM.cpNum(owner, r.u2())));
            case 'I': return Integer.valueOf((int) VM.cpNum(owner, r.u2()));
            case 'J': return Long.valueOf(VM.cpNum(owner, r.u2()));
            case 'S': return Short.valueOf((short) VM.cpNum(owner, r.u2()));
            case 'Z': return Boolean.valueOf(VM.cpNum(owner, r.u2()) != 0);
            case 's': return VM.cpUtf8(owner, r.u2());
            case 'e': {
                String td = VM.cpUtf8(owner, r.u2());
                String cn = VM.cpUtf8(owner, r.u2());
                Class<?> ec = VM.classOfDesc(td);
                if (ec == null) return null;
                try { return Enum.valueOf((Class) ec, cn); } catch (IllegalArgumentException e) { return null; }
            }
            case 'c': {
                String d = VM.cpUtf8(owner, r.u2());
                if (d.equals("V")) return void.class;
                return VM.classOfDesc(d);
            }
            case '@': return parseAnnotation(r, owner);
            case '[': {
                int n = r.u2();
                Class<?> comp = expected != null && expected.isArray() ? expected.getComponentType() : null;
                Object[] tmp = new Object[n];
                for (int i = 0; i < n; i++) tmp[i] = value(r, owner, comp);
                if (comp == null) {
                    if (n > 0 && tmp[0] != null) comp = tmp[0] instanceof Annotation ? ((Annotation) tmp[0]).annotationType() : tmp[0].getClass();
                    else comp = Object.class;
                }
                Object arr = Array.newInstance(comp, n);
                for (int i = 0; i < n; i++) if (tmp[i] != null) Array.set(arr, i, tmp[i]);
                return arr;
            }
        }
        throw new java.lang.annotation.AnnotationFormatError("Invalid member-value tag: " + (char) tag);
    }

    public static <T extends Annotation> T[] byType(Annotation[] all, Class<T> type) {
        ArrayList<T> out = new ArrayList<>();
        for (Annotation a : all) if (type.isInstance(a)) out.add(type.cast(a));
        Repeatable rep = type.getAnnotation(Repeatable.class);
        if (rep != null) {
            Class<? extends Annotation> cont = rep.value();
            for (Annotation a : all) {
                if (cont.isInstance(a)) {
                    try {
                        Method vm = cont.getDeclaredMethod("value");
                        T[] arr = (T[]) vm.invoke(a);
                        for (T x : arr) out.add(x);
                    } catch (Exception e) { }
                }
            }
        }
        return out.toArray((T[]) Array.newInstance(type, out.size()));
    }

    // ----- verifications d'acces -------------------------------------------
    public static Class<?> callerClass(int depth) {
        StackTraceElement[] st = new Throwable().getStackTrace();
        for (int i = 0; i < st.length; i++) {
            String cn = st[i].getClassName();
            if (cn.startsWith("java.lang.reflect.") || cn.equals("java.lang.Class")) continue;
            return VM.classOfName(cn);
        }
        return null;
    }
    private static String outermost(Class<?> c) {
        String n = c.getName();
        int i = n.indexOf('$');
        return i < 0 ? n : n.substring(0, i);
    }
    public static void checkMember(Class<?> caller, Class<?> decl, int mods) throws IllegalAccessException {
        if (caller == null || caller == decl) return;
        boolean ok;
        if ((mods & Modifier.PUBLIC) != 0) ok = true;
        else if ((mods & Modifier.PRIVATE) != 0) ok = outermost(caller).equals(outermost(decl));
        else if ((mods & Modifier.PROTECTED) != 0) ok = caller.getPackageName().equals(decl.getPackageName()) || decl.isAssignableFrom(caller);
        else ok = caller.getPackageName().equals(decl.getPackageName());
        if (!ok)
            throw new IllegalAccessException("class " + caller.getName() + " cannot access a member of class " + decl.getName() + modOf(decl)
                + " with modifiers \"" + Modifier.toString(mods & (Modifier.PUBLIC | Modifier.PROTECTED | Modifier.PRIVATE | Modifier.STATIC | Modifier.FINAL | Modifier.ABSTRACT | Modifier.SYNCHRONIZED | Modifier.NATIVE | Modifier.VOLATILE | Modifier.TRANSIENT)) + "\"");
    }
    private static String modOf(Class<?> c) {
        String n = c.getName();
        if (n.startsWith("java.awt.") || n.startsWith("javax.swing.") || n.startsWith("java.beans.")) return " (in module java.desktop)";
        if (n.startsWith("java.") || n.startsWith("javax.")) return " (in module java.base)";
        return "";
    }
    static Class<?> prim(Class<?> c) {
        if (c == Integer.class) return int.class;
        if (c == Long.class) return long.class;
        if (c == Double.class) return double.class;
        if (c == Float.class) return float.class;
        if (c == Boolean.class) return boolean.class;
        if (c == Character.class) return char.class;
        if (c == Short.class) return short.class;
        if (c == Byte.class) return byte.class;
        return c;
    }
    public static boolean canConvert(Class<?> from, Class<?> to) {
        from = prim(from);
        if (!from.isPrimitive() || !to.isPrimitive()) return false;
        if (from == to) return true;
        if (to == boolean.class || from == boolean.class) return false;
        if (to == short.class) return from == byte.class;
        if (to == char.class) return false;
        if (to == int.class) return from == byte.class || from == short.class || from == char.class;
        if (to == long.class) return from == byte.class || from == short.class || from == char.class || from == int.class;
        if (to == float.class) return from != double.class;
        if (to == double.class) return true;
        return false;
    }
    public static void checkArg(Class<?> ptype, Object arg) {
        if (ptype.isPrimitive()) {
            if (arg == null || !canConvert(arg.getClass(), ptype)) throw new IllegalArgumentException("argument type mismatch");
        } else if (arg != null && !ptype.isInstance(arg)) throw new IllegalArgumentException("argument type mismatch");
    }
    public static String tvString(TypeVariable<?> tv) {
        StringBuilder sb = new StringBuilder(tv.getName());
        Type[] b = tv.getBounds();
        if (b.length > 0 && !(b.length == 1 && b[0] == Object.class)) {
            sb.append(" extends ");
            for (int i = 0; i < b.length; i++) {
                if (i > 0) sb.append(" & ");
                sb.append(b[i].getTypeName());
            }
        }
        return sb.toString();
    }
}
