import java.lang.reflect.*;
import java.lang.annotation.*;
import java.util.*;
import java.util.function.*;

public class Refl2 {
    @Retention(RetentionPolicy.RUNTIME) @Inherited @interface Inh { String value(); }
    @Retention(RetentionPolicy.RUNTIME) @Repeatable(Roles.class) @interface Role { String value(); }
    @Retention(RetentionPolicy.RUNTIME) @interface Roles { Role[] value(); }
    @Retention(RetentionPolicy.RUNTIME) @interface Cfg { Class<?> k() default Void.class; Thread.State st() default Thread.State.NEW; double d() default 0; char[] cs() default {'a','\n'}; String s() default "q\"uote"; long l() default 0; float f() default Float.NaN; }
    @Inh("base") @Role("a") @Role("b") static class A {}
    static class B extends A {}
    @Cfg(k = int[].class, st = Thread.State.BLOCKED, d = 2.5, cs = {'x'}, l = -1) static class C {}
    @Cfg static class D {}
    static class Priv { private void p() {} void pk() {} protected void pr() {} public void pu() {} private static int x; }
    interface I { void f(); static void s() {} default void d() {} }
    static class Gen<T, U extends List<? extends T>> { T t; U u; List<T>[] arr; Map<String, List<U>> m; public <V extends T> V f(V v, T... ts) { return v; } }
    static class Outer<X> { class In<Y> { Map<X, Y> m; } }
    static void main2() throws Exception {
        System.out.println(Arrays.toString(B.class.getAnnotations()));
        System.out.println(Arrays.toString(B.class.getDeclaredAnnotations()));
        System.out.println(Arrays.toString(A.class.getAnnotationsByType(Role.class)));
        System.out.println(A.class.getAnnotation(Roles.class));
        System.out.println(A.class.getAnnotation(Role.class));
        Cfg c = C.class.getAnnotation(Cfg.class), dd = D.class.getAnnotation(Cfg.class);
        System.out.println(c + "\n" + dd);
        System.out.println(c.equals(dd) + " " + dd.equals(D.class.getAnnotation(Cfg.class)) + " " + (dd.hashCode() == D.class.getAnnotation(Cfg.class).hashCode()) + " " + c.annotationType());
        System.out.println(c.k() + " " + c.st() + " " + Arrays.toString(c.cs()) + " " + c.l());
        for (String n : new String[]{"p", "pk", "pr", "pu"}) {
            Method m = Priv.class.getDeclaredMethod(n);
            m.invoke(new Priv());
            System.out.println(n + " ok");
        }
        System.out.println(Arrays.toString(I.class.getMethods().length > 0 ? new int[]{I.class.getMethods().length, I.class.getDeclaredMethods().length} : null));
        System.out.println(I.class.getMethod("d").isDefault() + " " + I.class.getMethod("f").isDefault() + " " + Modifier.toString(I.class.getMethod("s").getModifiers()));
        Class<?> g = Gen.class;
        for (Field f : g.getDeclaredFields()) System.out.println(f.getName() + " " + f.getGenericType() + " " + f.toGenericString());
        Method f = g.getMethod("f", Object.class, Object[].class);
        System.out.println(f.toGenericString() + " " + f.isVarArgs() + " " + Arrays.toString(f.getGenericParameterTypes()) + " " + Arrays.toString(f.getTypeParameters()[0].getBounds()));
        TypeVariable<?>[] tv = g.getTypeParameters();
        System.out.println(Arrays.toString(tv) + " " + Arrays.toString(tv[1].getBounds()) + " " + tv[1].getGenericDeclaration() + " " + g.toGenericString());
        ParameterizedType pt = (ParameterizedType) Outer.In.class.getDeclaredField("m").getGenericType();
        System.out.println(pt + " " + pt.getRawType() + " " + pt.getOwnerType() + " " + Arrays.toString(pt.getActualTypeArguments()));
        WildcardType wt = (WildcardType) ((ParameterizedType) tv[1].getBounds()[0]).getActualTypeArguments()[0];
        System.out.println(wt + " " + Arrays.toString(wt.getUpperBounds()) + " " + Arrays.toString(wt.getLowerBounds()));
        Parameter[] ps = f.getParameters();
        System.out.println(Arrays.toString(ps) + " " + ps[0].isNamePresent() + " " + ps[1].isVarArgs());
        System.out.println(Arrays.toString(ArrayList.class.getGenericInterfaces()));
        System.out.println(ArrayList.class.getGenericSuperclass() + " " + Arrays.toString(ArrayList.class.getTypeParameters()));
        System.out.println(HashMap.class.getMethod("get", Object.class).getGenericReturnType() + " " + Map.class.getMethod("entrySet").getGenericReturnType());
    }
    public static void main(String[] args) throws Exception {
        main2();
        try { Priv.class.getDeclaredField("x").get(null); System.out.println("same-nest ok"); } catch (IllegalAccessException e) { System.out.println(e.getMessage()); }
        Object o = Class.forName("Refl2$Priv").getDeclaredConstructor().newInstance();
        System.out.println(o.getClass().getName() + " " + Modifier.toString(Priv.class.getModifiers()) + " " + Modifier.toString(Priv.class.getDeclaredMethod("pr").getModifiers()));
        try { Class.forName("no.Such"); } catch (ClassNotFoundException e) { System.out.println("CNF " + e.getMessage()); }
        try { A.class.getDeclaredConstructor().newInstance(); System.out.println("A ok"); } catch (Exception e) { System.out.println(e); }
        try { I.class.getMethod("f").invoke(null); } catch (Exception e) { System.out.println(e.getClass().getName()); }
        try { Runnable.class.getDeclaredConstructor(); } catch (Exception e) { System.out.println(e); }
        try { Thread.State.class.getDeclaredConstructors()[0].newInstance("A", 1); } catch (Exception e) { System.out.println(e); }
        System.out.println(int.class + " " + int[].class.getName() + " " + int[][].class.getTypeName() + " " + String[].class.getCanonicalName() + " " + Map.Entry.class.getCanonicalName() + " " + Map.Entry.class.getName());
        System.out.println(int.class.getModifiers() + " " + int[].class.getModifiers() + " " + Runnable.class.getModifiers() + " " + Map.Entry.class.getModifiers());
        System.out.println(int.class.descriptorString() + String[][].class.descriptorString() + Object.class.descriptorString());
    }
}
