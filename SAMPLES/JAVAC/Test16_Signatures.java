import java.lang.reflect.*;
import java.util.*;
import java.util.function.*;

public class Test16_Signatures<T extends Comparable<T>, U> extends ArrayList<T> implements Supplier<Map<String, ? extends U>> {
    public List<String> a;
    public Map<String, List<? super Integer>> b;
    public T[] c;
    public List<?>[] d;
    public int plain;
    public Map.Entry<String, T> e;
    public <X extends Number & Comparable<X>, Y> X gen(List<? extends X> in, Y[] y, Map<T, ? super Y> m) throws Exception { return null; }
    public <E extends Exception> void thrower(Supplier<E> s) throws E {}
    public void plainM(int x, String s) {}
    public List<T> ret(T... ts) { return null; }
    public Map<String, ? extends U> get() { return null; }
    Test16_Signatures(List<T> l, int k) {}
    interface I<Q> { Q q(); }
    enum En { A, B }
    record R<Z>(List<Z> items, int n, Z z) {}
    static <K> void thr() throws java.io.IOException, InterruptedException {}
    static String t(Type ty) { return ty.getTypeName(); }
    public static void main(String[] args) throws Exception {
        Class<?> c = Test16_Signatures.class;
        System.out.println(Arrays.toString(c.getTypeParameters()) + " " + Arrays.toString(c.getTypeParameters()[0].getBounds()));
        System.out.println(t(c.getGenericSuperclass()));
        for (Type t : c.getGenericInterfaces()) System.out.println(t(t));
        for (String n : new String[]{"a","b","c","d","plain","e"}) System.out.println(n + " " + t(c.getField(n).getGenericType()));
        Method[] ms = c.getDeclaredMethods();
        Arrays.sort(ms, Comparator.comparing(Method::getName).thenComparing(m -> m.getParameterCount()));
        for (Method m : ms) {
            if (m.isSynthetic() || m.getName().equals("main") || m.getName().equals("t")) continue;
            System.out.println(m.getName() + " " + Arrays.toString(m.getTypeParameters()) + " " + t(m.getGenericReturnType())
                + " " + Arrays.toString(Arrays.stream(m.getGenericParameterTypes()).map(Test16_Signatures::t).toArray())
                + " " + Arrays.toString(Arrays.stream(m.getGenericExceptionTypes()).map(Test16_Signatures::t).toArray())
                + " " + Arrays.toString(m.getExceptionTypes()));
        }
        Constructor<?> k = c.getDeclaredConstructors()[0];
        System.out.println(Arrays.toString(k.getGenericParameterTypes()));
        System.out.println(Arrays.toString(I.class.getTypeParameters()));
        System.out.println(En.class.getGenericSuperclass());
        System.out.println(R.class.getRecordComponents()[0].getGenericType());
        System.out.println(R.class.getMethod("items").getGenericReturnType());
        System.out.println(Arrays.toString(R.class.getTypeParameters()));
        Object o = new ArrayList<String>() {};
        System.out.println(o.getClass().getGenericSuperclass());
        Object o2 = new Supplier<List<Integer>>() { public List<Integer> get() { return null; } };
        System.out.println(Arrays.toString(o2.getClass().getGenericInterfaces()));
    }
}
