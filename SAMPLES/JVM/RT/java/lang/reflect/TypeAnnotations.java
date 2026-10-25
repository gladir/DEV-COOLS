package java.lang.reflect;
import java.lang.annotation.Annotation;
import java.util.ArrayList;
final class TypeAnnotations {
    private TypeAnnotations() {}
    private static final class Entry {
        String path;
        Annotation anno;
    }
    private static final Annotation[] NONE = new Annotation[0];
    static AnnotatedType annotate(Type t, byte[] attr, Class<?> owner, int target, int index) {
        ArrayList<Entry> es = new ArrayList<>();
        if (attr != null) parseEntries(attr, owner, target, index, es);
        return build(t, "", es);
    }
    private static void parseEntries(byte[] b, Class<?> owner, int wantTarget, int wantIndex, ArrayList<Entry> out) {
        int[] pos = {0};
        int n = u2(b, pos);
        for (int i = 0; i < n; i++) {
            int tt = u1(b, pos);
            int idx = 0;
            switch (tt) {
                case 0x00: case 0x01: idx = u1(b, pos); break;
                case 0x10: idx = u2(b, pos); break;
                case 0x11: case 0x12: idx = u1(b, pos); u1(b, pos); break;
                case 0x13: case 0x14: case 0x15: break;
                case 0x16: idx = u1(b, pos); break;
                case 0x17: idx = u2(b, pos); break;
                default: break;
            }
            int pl = u1(b, pos);
            StringBuilder path = new StringBuilder();
            for (int k = 0; k < pl; k++) {
                int kind = u1(b, pos);
                int arg = u1(b, pos);
                path.append(kind).append(',').append(arg).append(';');
            }
            // annotation : on la reparse a partir de la position courante
            byte[] rest = new byte[b.length - pos[0] + 2];
            rest[0] = 0; rest[1] = 1;
            System.arraycopy(b, pos[0], rest, 2, b.length - pos[0]);
            int[] used = new int[1];
            Annotation[] a = AnnotationSupport.parseOne(rest, owner, used);
            pos[0] += used[0];
            if (tt == wantTarget && idx == wantIndex && a.length > 0) {
                Entry e = new Entry();
                e.path = path.toString();
                e.anno = a[0];
                out.add(e);
            }
        }
    }
    private static int u1(byte[] b, int[] p) { return b[p[0]++] & 255; }
    private static int u2(byte[] b, int[] p) { int v = ((b[p[0]] & 255) << 8) | (b[p[0] + 1] & 255); p[0] += 2; return v; }

    private static Annotation[] annosAt(String path, ArrayList<Entry> es) {
        ArrayList<Annotation> r = new ArrayList<>();
        for (Entry e : es) if (e.path.equals(path)) r.add(e.anno);
        return r.toArray(NONE);
    }
    private static int innerDepth(Class<?> c) {
        int d = 0;
        while (c != null && c.isMemberClass() && !Modifier.isStatic(c.getModifiers()) && !c.isInterface()) { d++; c = c.getDeclaringClass(); }
        return d;
    }
    private static AnnotatedType build(Type t, String path, ArrayList<Entry> es) {
        if (t instanceof Class) {
            Class<?> c = (Class<?>) t;
            if (c.isArray()) {
                return new AnnotatedArrayTypeImpl(c, annosAt(path, es), build(c.getComponentType(), path + "0,0;", es));
            }
            StringBuilder p = new StringBuilder(path);
            for (int i = innerDepth(c); i > 0; i--) p.append("1,0;");
            return new AnnotatedTypeImpl(c, annosAt(p.toString(), es));
        }
        if (t instanceof ParameterizedType) {
            ParameterizedType pt = (ParameterizedType) t;
            Type[] as = pt.getActualTypeArguments();
            AnnotatedType[] aa = new AnnotatedType[as.length];
            Class<?> raw = (Class<?>) pt.getRawType();
            StringBuilder p = new StringBuilder(path);
            for (int i = innerDepth(raw); i > 0; i--) p.append("1,0;");
            for (int i = 0; i < as.length; i++) aa[i] = build(as[i], p + "3," + i + ";", es);
            return new AnnotatedParameterizedTypeImpl(pt, annosAt(p.toString(), es), aa);
        }
        if (t instanceof GenericArrayType) {
            return new AnnotatedArrayTypeImpl(t, annosAt(path, es), build(((GenericArrayType) t).getGenericComponentType(), path + "0,0;", es));
        }
        if (t instanceof WildcardType) {
            WildcardType w = (WildcardType) t;
            Type[] u = w.getUpperBounds(), l = w.getLowerBounds();
            AnnotatedType[] ua = new AnnotatedType[u.length], la = new AnnotatedType[l.length];
            for (int i = 0; i < u.length; i++) ua[i] = build(u[i], path + "2,0;", es);
            for (int i = 0; i < l.length; i++) la[i] = build(l[i], path + "2,0;", es);
            return new AnnotatedWildcardTypeImpl(w, annosAt(path, es), ua, la);
        }
        if (t instanceof TypeVariable) return new AnnotatedTypeVariableImpl(t, annosAt(path, es));
        return new AnnotatedTypeImpl(t, annosAt(path, es));
    }
}
