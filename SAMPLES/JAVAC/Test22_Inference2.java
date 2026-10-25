import java.util.*;
import java.util.function.*;
import java.io.Serializable;

public class Test22_Inference2 {
    static <T extends Number & Comparable<T>> T maxOf(List<T> l) {
        T best = l.get(0);
        for (T t : l) if (t.compareTo(best) > 0) best = t;
        System.out.println(best.intValue());
        return best;
    }
    static <T extends Comparable<? super T>> void sortIt(List<T> l) { Collections.sort(l); }
    static double sum(Collection<? extends Number> c) { double s = 0; for (Number n : c) s += n.doubleValue(); return s; }
    static void fill(List<? super Integer> l) { l.add(1); l.add(2); }
    static <K, V extends Comparable<V>> K argMax(Map<K, V> m) {
        K bk = null; V bv = null;
        for (Map.Entry<K, V> e : m.entrySet()) if (bv == null || e.getValue().compareTo(bv) > 0) { bk = e.getKey(); bv = e.getValue(); }
        return bk;
    }
    static <T> void swap(List<T> l, int i, int j) { T t = l.get(i); l.set(i, l.get(j)); l.set(j, t); }
    static void swapAny(List<?> l) { swapHelper(l); }
    private static <T> void swapHelper(List<T> l) { T t = l.get(0); l.set(0, l.get(1)); l.set(1, t); }
    interface Shape extends Comparable<Shape> { double area(); default int compareTo(Shape o) { return Double.compare(area(), o.area()); } }
    record Sq(double s) implements Shape { public double area() { return s * s; } }
    record Ci(double r) implements Shape { public double area() { return 3 * r * r; } }
    static <T extends Shape> T biggest(List<? extends T> l) { return Collections.max(l); }
    public static void main(String[] args) {
        System.out.println(maxOf(Arrays.asList(3, 9, 4)));
        List<String> ls = new ArrayList<>(List.of("b", "a")); sortIt(ls); System.out.println(ls);
        System.out.println(sum(List.of(1, 2.5, 3L)));
        List<Number> ln = new ArrayList<>(); fill(ln); System.out.println(ln);
        List<Object> lo = new ArrayList<>(); fill(lo); System.out.println(lo);
        System.out.println(argMax(Map.of("a", 1, "b", 5)));
        List<String> l2 = new ArrayList<>(List.of("x", "y", "z")); swap(l2, 0, 2); swapAny(l2); System.out.println(l2);
        Shape b = biggest(List.of(new Sq(2), new Sq(3)));
        System.out.println(b.area());
        Runnable r = (Runnable & Serializable) () -> System.out.println("ser");
        r.run();
        System.out.println(r instanceof Serializable);
        Comparator<String> cmp = (Comparator<String> & Serializable) (x, y) -> x.length() - y.length();
        System.out.println(cmp.compare("aa", "b"));
        List<? extends Number> wl = List.of(1, 2);
        Number first = wl.get(0);
        System.out.println(first);
        Map<String, List<? extends CharSequence>> mm = new HashMap<>();
        mm.put("k", List.of("s", new StringBuilder("sb")));
        for (CharSequence cs : mm.get("k")) System.out.print(cs.length());
        System.out.println();
        Comparator<Map.Entry<String, Integer>> byVal = Map.Entry.comparingByValue();
        List<Map.Entry<String, Integer>> es = new ArrayList<>(Map.of("a", 3, "b", 1).entrySet());
        es.sort(byVal.reversed());
        System.out.println(es);
        Object o = Collections.emptyList();
        List<String> el = Collections.emptyList();
        System.out.println(o + "" + el);
    }
}
