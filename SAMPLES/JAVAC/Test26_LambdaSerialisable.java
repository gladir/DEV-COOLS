import java.io.*;
import java.util.*;
import java.util.function.*;
public class Test26_LambdaSerialisable {
    interface Mark {}
    int base = 100;
    Supplier<Integer> inst() { return (Supplier<Integer> & Serializable) () -> base + 1; }
    public static void main(String[] a) throws Exception {
        int k = 5; String s = "cap";
        Runnable r1 = (Runnable & Serializable) () -> System.out.println("a" + k + s);
        Runnable r2 = (Runnable & Mark) () -> System.out.println("b");
        Runnable r3 = (Runnable & Serializable & Mark) () -> System.out.println("c");
        Comparator<String> cmp = (Comparator<String> & Serializable) (x, y) -> y.compareTo(x);
        long big = 7L; double dd = 2.5;
        Function<Integer, Double> f = (Function<Integer, Double> & Serializable) i -> i * dd + big;
        r1.run(); r2.run(); r3.run();
        System.out.println((r1 instanceof Serializable) + " " + (r2 instanceof Serializable) + " " + (r3 instanceof Mark) + " " + (r3 instanceof Serializable));
        Object[] objs = { r1, cmp, f, new Test26_LambdaSerialisable().inst() };
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ObjectOutputStream oo = new ObjectOutputStream(bo)) { for (Object o : objs) oo.writeObject(o); }
        try (ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(bo.toByteArray()))) {
            ((Runnable) oi.readObject()).run();
            @SuppressWarnings("unchecked") Comparator<String> c2 = (Comparator<String>) oi.readObject();
            System.out.println(c2.compare("a", "b"));
            @SuppressWarnings("unchecked") Function<Integer, Double> f2 = (Function<Integer, Double>) oi.readObject();
            System.out.println(f2.apply(4));
            @SuppressWarnings("unchecked") Supplier<Integer> s2 = (Supplier<Integer>) oi.readObject();
            System.out.println(s2.get());
        }
    }
}
