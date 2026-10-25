import java.lang.reflect.*;
import java.lang.annotation.*;
import java.util.*;
import java.util.function.*;

public class Refl1 {
    @Retention(RetentionPolicy.RUNTIME) @interface Tag { String value() default "x"; int[] n() default {}; }
    interface Greeter { String greet(String who); default int twice(int x) { return 2 * x; } }
    static abstract class Base implements Comparable<Base> {
        protected int id = 7;
        public static final String NAME = "base";
        public int compareTo(Base o) { return 0; }
        public abstract void run() throws java.io.IOException;
    }
    @Tag("cls") public static class Impl extends Base implements Greeter, java.io.Serializable {
        private int secret = 42;
        public String label = "L";
        public static int counter = 3;
        public final long big = 99L;
        transient volatile double d = 1.5;
        public Impl() {}
        public Impl(int secret, String label) { this.secret = secret; this.label = label; }
        private Impl(String s) { label = s; }
        public void run() {}
        public String greet(String who) { return "hi " + who + label; }
        private int hidden(int a, long b) { return (int) (a + b + secret); }
        public static int sum(int... xs) { int s = 0; for (int x : xs) s += x; return s; }
        public void boom() { throw new IllegalStateException("boom"); }
        @Tag(value = "m", n = {1, 2}) @Deprecated public synchronized double mix(double a, float b, char c, boolean z, byte y, short s) { return a + b + c + (z ? 1 : 0) + y + s; }
        public <T extends Comparable<T>> List<T> gen(Map<String, ? super T> m, T[] arr) { return null; }
        public String toString() { return "Impl" + secret; }
    }
    enum Color { RED, GREEN; int v() { return ordinal(); } }
    record Pt(int x, String y) {}

    static String ms(Member m) { return Modifier.toString(m.getModifiers()) + "|" + m.getName(); }

    public static void main(String[] args) throws Exception {
        Class<?> c = Impl.class;
        System.out.println(c + " " + c.getName() + " " + c.getSimpleName() + " " + c.getCanonicalName() + " " + Modifier.toString(c.getModifiers()));
        System.out.println(c.getSuperclass() + " " + Arrays.toString(c.getInterfaces()) + " " + c.getEnclosingClass() + " " + c.getDeclaringClass());
        Field[] fs = c.getDeclaredFields();
        for (Field f : fs) System.out.println(f + " ## " + ms(f) + " " + f.getType() + " " + f.getGenericType());
        Method[] ms = c.getDeclaredMethods();
        Arrays.sort(ms, Comparator.comparing(Method::getName));
        for (Method m : ms) System.out.println(m + " ## " + (m.isVarArgs() ? "varargs" : "") + (m.isBridge() ? "bridge" : "") + (m.isSynthetic() ? "synth" : ""));
        Constructor<?>[] cs = c.getDeclaredConstructors();
        Arrays.sort(cs, Comparator.comparing(Constructor::getParameterCount));
        for (Constructor<?> k : cs) System.out.println(k + " ## " + k.getParameterCount());
        List<String> pub = new ArrayList<>();
        for (Method m : c.getMethods()) pub.add(m.getDeclaringClass().getSimpleName() + "." + m.getName() + m.getParameterCount());
        Collections.sort(pub);
        System.out.println(pub);
        List<String> pf = new ArrayList<>();
        for (Field f : c.getFields()) pf.add(f.getName());
        Collections.sort(pf);
        System.out.println(pf);
        Object o = c.getConstructor(int.class, String.class).newInstance(5, "Q");
        System.out.println(o + " " + c.getMethod("greet", String.class).invoke(o, "bob"));
        Field sec = c.getDeclaredField("secret");
        try { sec.get(o); System.out.println("no check"); } catch (IllegalAccessException e) { System.out.println("IAE " + e.getMessage()); }
        sec.setAccessible(true);
        System.out.println(sec.get(o) + " " + sec.getInt(o));
        sec.set(o, 11); sec.setInt(o, 12);
        System.out.println(o);
        Method h = c.getDeclaredMethod("hidden", int.class, long.class);
        h.setAccessible(true);
        System.out.println(h.invoke(o, 1, 2L) + " " + h.invoke(o, (short) 3, 4));
        System.out.println(c.getMethod("sum", int[].class).invoke(null, (Object) new int[]{1, 2, 3}));
        try { c.getMethod("boom").invoke(o); } catch (InvocationTargetException e) { System.out.println("ITE " + e.getCause() + " " + e.getMessage()); }
        try { c.getMethod("greet", String.class).invoke(o, 5); } catch (IllegalArgumentException e) { System.out.println("IAE " + e.getMessage()); }
        try { c.getMethod("greet", String.class).invoke(o); } catch (IllegalArgumentException e) { System.out.println("IAE " + e.getMessage()); }
        try { c.getMethod("greet", String.class).invoke("zz", "a"); } catch (IllegalArgumentException e) { System.out.println("IAE " + e.getMessage()); }
        try { c.getMethod("nope"); } catch (NoSuchMethodException e) { System.out.println("NSM " + e.getMessage()); }
        try { c.getField("nope"); } catch (NoSuchFieldException e) { System.out.println("NSF " + e.getMessage()); }
        try { c.getConstructor(int.class); } catch (NoSuchMethodException e) { System.out.println("NSM " + e.getMessage()); }
        Method mix = c.getMethod("mix", double.class, float.class, char.class, boolean.class, byte.class, short.class);
        System.out.println(mix.invoke(o, 1.0, 2f, 'a', true, (byte) 3, (short) 4));
        System.out.println(mix + " | " + mix.toGenericString());
        System.out.println(Arrays.toString(mix.getAnnotations()));
        System.out.println(c.getAnnotation(Tag.class) + " " + c.isAnnotationPresent(Tag.class));
        System.out.println(c.getMethod("gen", Map.class, Comparable[].class).toGenericString());
        Constructor<?> pk = c.getDeclaredConstructor(String.class);
        pk.setAccessible(true);
        System.out.println(pk.newInstance("pp") + " " + ((Impl) pk.newInstance("pp")).label);
        Field st = c.getField("counter");
        st.setInt(null, 10);
        System.out.println(Impl.counter + " " + st.get(null));
        Field fin = c.getField("big");
        try { fin.set(o, 1L); } catch (IllegalAccessException e) { System.out.println("IAE " + e.getMessage()); }
        System.out.println(fin.getLong(o) + " " + fin.getDouble(o));
        try { sec.set(o, "str"); } catch (IllegalArgumentException e) { System.out.println("IAE " + e.getMessage()); }
        Field dd = c.getDeclaredField("d");
        System.out.println(Modifier.toString(dd.getModifiers()));
        // base
        System.out.println(Base.class.getDeclaredField("id").getModifiers() + " " + Modifier.toString(Base.class.getModifiers()));
        System.out.println(Arrays.toString(Base.class.getGenericInterfaces()) + " " + Base.class.getDeclaredMethod("run").getExceptionTypes()[0]);
        // Proxy
        Greeter g = (Greeter) Proxy.newProxyInstance(Refl1.class.getClassLoader(), new Class<?>[]{Greeter.class}, (p, m, a) -> {
            if (m.getName().equals("greet")) return "proxy:" + a[0];
            if (m.getName().equals("twice")) return (Integer) a[0] + 100;
            if (m.getName().equals("toString")) return "PX";
            if (m.getName().equals("hashCode")) return 5;
            return null;
        });
        System.out.println(g.greet("w") + " " + g.twice(4) + " " + g + " " + g.hashCode() + " " + Proxy.isProxyClass(g.getClass()) + " " + (g instanceof Greeter));
        Runnable r = (Runnable) Proxy.newProxyInstance(null, new Class<?>[]{Runnable.class}, (p, m, a) -> { throw new java.io.IOException("chk"); });
        try { r.run(); } catch (UndeclaredThrowableException e) { System.out.println("UTE " + e.getCause()); }
        // enum / record / arrays
        System.out.println(Arrays.toString(Color.class.getEnumConstants()) + " " + Color.class.isEnum() + " " + Color.class.getField("RED").isEnumConstant());
        System.out.println(Color.class.getMethod("valueOf", String.class).invoke(null, "GREEN"));
        for (RecordComponent rc : Pt.class.getRecordComponents()) System.out.println(rc + " " + rc.getAccessor().invoke(new Pt(3, "s")));
        Object arr = Array.newInstance(int.class, 3);
        Array.setInt(arr, 1, 5); Array.set(arr, 2, 9);
        System.out.println(Arrays.toString((int[]) arr) + " " + Array.getLength(arr) + " " + Array.get(arr, 1));
        Object m2 = Array.newInstance(String.class, 2, 3);
        System.out.println(m2.getClass().getSimpleName() + " " + ((Object[]) m2).length);
        System.out.println(Arrays.toString(Refl1.class.getDeclaredClasses().length > 0 ? new int[]{Refl1.class.getDeclaredClasses().length} : null));
        Class<?> anon = new Object() {}.getClass();
        System.out.println(anon.isAnonymousClass() + " " + anon.getEnclosingMethod() + " " + anon.getEnclosingClass());
        class Loc {}
        System.out.println(Loc.class.isLocalClass() + " " + Loc.class.getEnclosingMethod().getName() + " " + Loc.class.getSimpleName());
        System.out.println(Class.forName("java.util.ArrayList").getMethod("size").invoke(new ArrayList<>(List.of(1, 2))));
        System.out.println(String.class.getMethod("length").invoke("hello") + " " + String.class.getMethod("substring", int.class, int.class).invoke("hello", 1, 3));
        System.out.println(Integer.class.getMethod("parseInt", String.class).invoke(null, "123"));
        Supplier<String> sup = () -> "lam";
        System.out.println(sup.getClass().getInterfaces()[0] + " " + sup.getClass().isSynthetic());
    }
}
