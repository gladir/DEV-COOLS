package java.lang.reflect;
import java.util.ArrayList;
public final class Generics {
    private final String s;
    private int p;
    private final GenericDeclaration scope;
    private Generics(String s, int p, GenericDeclaration scope) { this.s = s; this.p = p; this.scope = scope; }

    static GenericDeclaration outer(GenericDeclaration d) {
        if (d instanceof Class) {
            Class<?> c = (Class<?>) d;
            GenericDeclaration m = c.enclosingExecutable();
            if (m != null) return m;
            return c.getEnclosingClass();
        }
        if (d instanceof Executable) return ((Executable) d).getDeclaringClass();
        return null;
    }
    static TypeVariable<?> lookup(String name, GenericDeclaration d) {
        while (d != null) {
            for (TypeVariable<?> tv : d.getTypeParameters()) if (tv.getName().equals(name)) return tv;
            d = outer(d);
        }
        throw new TypeNotPresentException(name, null);
    }

    /** Parametres de type : renvoie les variables ; sig commence par '<' sinon tableau vide */
    public static TypeVariable<?>[] typeParams(String sig, GenericDeclaration decl) {
        if (sig == null || sig.length() == 0 || sig.charAt(0) != '<') return new TypeVariable<?>[0];
        Generics g = new Generics(sig, 1, decl);
        ArrayList<TypeVariable<?>> out = new ArrayList<>();
        while (g.s.charAt(g.p) != '>') {
            int c = g.s.indexOf(':', g.p);
            String name = g.s.substring(g.p, c);
            g.p = c;
            int start = g.p;
            while (g.s.charAt(g.p) == ':') {
                g.p++;
                if (g.s.charAt(g.p) != ':') g.skipType();
            }
            out.add(new TypeVariableImpl<GenericDeclaration>(decl, name, g.s.substring(start, g.p)));
        }
        return out.toArray(new TypeVariable<?>[0]);
    }
    static int afterParams(String sig) {
        if (sig.charAt(0) != '<') return 0;
        Generics g = new Generics(sig, 1, null);
        while (g.s.charAt(g.p) != '>') {
            g.p = g.s.indexOf(':', g.p);
            while (g.s.charAt(g.p) == ':') {
                g.p++;
                if (g.s.charAt(g.p) != ':') g.skipType();
            }
        }
        return g.p + 1;
    }
    static Type[] parseBounds(String boundSig, GenericDeclaration decl) {
        Generics g = new Generics(boundSig, 0, decl);
        ArrayList<Type> out = new ArrayList<>();
        while (g.p < g.s.length() && g.s.charAt(g.p) == ':') {
            g.p++;
            if (g.p < g.s.length() && g.s.charAt(g.p) != ':') out.add(g.type());
        }
        if (out.isEmpty()) out.add(Object.class);
        return out.toArray(new Type[0]);
    }
    private void skipType() {
        char c = s.charAt(p);
        if (c == '[') { p++; skipType(); }
        else if (c == 'T') { p = s.indexOf(';', p) + 1; }
        else if (c == 'L') {
            int depth = 0;
            while (true) {
                char d = s.charAt(p++);
                if (d == '<') depth++;
                else if (d == '>') depth--;
                else if (d == ';' && depth == 0) break;
            }
        } else p++;
    }
    /** une signature de classe : classe parente puis interfaces */
    public static Type[] classTypes(String sig, GenericDeclaration decl) {
        Generics g = new Generics(sig, afterParams(sig), decl);
        ArrayList<Type> out = new ArrayList<>();
        while (g.p < sig.length()) out.add(g.type());
        return out.toArray(new Type[0]);
    }
    public static Type fieldType(String sig, GenericDeclaration decl) { return new Generics(sig, 0, decl).type(); }
    public static Type[] methodParams(String sig, GenericDeclaration decl) {
        Generics g = new Generics(sig, afterParams(sig), decl);
        g.p++;
        ArrayList<Type> out = new ArrayList<>();
        while (g.s.charAt(g.p) != ')') out.add(g.type());
        return out.toArray(new Type[0]);
    }
    public static Type methodReturn(String sig, GenericDeclaration decl) {
        Generics g = new Generics(sig, afterParams(sig), decl);
        g.p = sig.indexOf(')', g.p) ;
        // ')' peut apparaitre dans un type ? non : seuls les noms et ; < > : / . [ T L
        g.p++;
        return g.type();
    }
    /** exceptions declarees dans la signature ; null s'il n'y en a pas */
    public static Type[] methodThrows(String sig, GenericDeclaration decl) {
        Generics g = new Generics(sig, afterParams(sig), decl);
        g.p = sig.indexOf(')', g.p) + 1;
        g.skipType();
        if (g.p >= sig.length()) return null;
        ArrayList<Type> out = new ArrayList<>();
        while (g.p < sig.length() && sig.charAt(g.p) == '^') { g.p++; out.add(g.type()); }
        return out.toArray(new Type[0]);
    }

    private Type type() {
        char c = s.charAt(p);
        switch (c) {
            case 'B': p++; return byte.class;
            case 'C': p++; return char.class;
            case 'D': p++; return double.class;
            case 'F': p++; return float.class;
            case 'I': p++; return int.class;
            case 'J': p++; return long.class;
            case 'S': p++; return short.class;
            case 'Z': p++; return boolean.class;
            case 'V': p++; return void.class;
            case '[': {
                p++;
                Type comp = type();
                if (comp instanceof Class) return Array.newInstance((Class<?>) comp, 0).getClass();
                return new GenericArrayTypeImpl(comp);
            }
            case 'T': {
                int e = s.indexOf(';', p);
                String n = s.substring(p + 1, e);
                p = e + 1;
                return lookup(n, scope);
            }
            default: return classType();
        }
    }
    private Type classType() {
        p++; // L
        int st = p;
        while (s.charAt(p) != '<' && s.charAt(p) != ';' && s.charAt(p) != '.') p++;
        String name = s.substring(st, p);
        Type t = load(name);
        boolean any = false;
        Type[] args = null;
        if (s.charAt(p) == '<') { args = typeArgs(); }
        if (args != null) t = new ParameterizedTypeImpl((Class<?>) t, args, null);
        while (s.charAt(p) == '.') {
            p++;
            int st2 = p;
            while (s.charAt(p) != '<' && s.charAt(p) != ';' && s.charAt(p) != '.') p++;
            name = name + "$" + s.substring(st2, p);
            Class<?> raw = (Class<?>) load(name);
            Type[] a2 = null;
            if (s.charAt(p) == '<') a2 = typeArgs();
            if (a2 != null || t instanceof ParameterizedType) t = new ParameterizedTypeImpl(raw, a2 == null ? new Type[0] : a2, t);
            else t = raw;
        }
        p++; // ;
        return t;
    }
    private Type load(String internal) {
        Class<?> c = VM.classOfName(internal);
        if (c == null) throw new TypeNotPresentException(internal.replace('/', '.'), null);
        return c;
    }
    private Type[] typeArgs() {
        p++;
        ArrayList<Type> out = new ArrayList<>();
        while (s.charAt(p) != '>') {
            char c = s.charAt(p);
            if (c == '*') { p++; out.add(new WildcardTypeImpl(new Type[]{Object.class}, new Type[0])); }
            else if (c == '+') { p++; out.add(new WildcardTypeImpl(new Type[]{type()}, new Type[0])); }
            else if (c == '-') { p++; out.add(new WildcardTypeImpl(new Type[]{Object.class}, new Type[]{type()})); }
            else out.add(type());
        }
        p++;
        return out.toArray(new Type[0]);
    }
}
