import java.util.*;
import java.util.function.*;
import java.util.stream.*;

public class Test27_Jokers {
    static double sum(Collection<? extends Number> c) { double s = 0; for (Number n : c) s += n.doubleValue(); return s; }
    static void fill(List<? super Integer> l) { for (int i = 0; i < 3; i++) l.add(i); }
    static int count(List<?> l) { return l.size(); }
    static <T> void copy(List<? super T> dst, List<? extends T> src) { for (T t : src) dst.add(t); }
    static <T extends Comparable<? super T>> T max(Collection<? extends T> c) {
        Iterator<? extends T> it = c.iterator(); T best = it.next();
        while (it.hasNext()) { T x = it.next(); if (x.compareTo(best) > 0) best = x; }
        return best;
    }
    static void swapHelper(List<?> l) { swap2(l); }
    static <E> void swap2(List<E> l) { E t = l.get(0); l.set(0, l.get(1)); l.set(1, t); }
    static class Animal implements Comparable<Animal> { String n; Animal(String n) { this.n = n; } public int compareTo(Animal o) { return n.compareTo(o.n); } public String toString() { return n; } }
    static class Dog extends Animal { Dog(String n) { super(n); } }
    public static void main(String[] args) {
        List<Integer> li = new ArrayList<>(List.of(3, 1, 2));
        List<Double> ld = List.of(1.5, 2.5);
        System.out.println(sum(li) + sum(ld));
        List<Number> ln = new ArrayList<>(); fill(ln); System.out.println(ln);
        List<Object> lo = new ArrayList<>(); fill(lo); System.out.println(lo);
        System.out.println(count(li) + count(ld));
        List<Object> dst = new ArrayList<>(); copy(dst, li); copy(dst, ld); System.out.println(dst);
        System.out.println(max(li));
        List<Dog> dogs = List.of(new Dog("a"), new Dog("z"), new Dog("m"));
        System.out.println(max(dogs));
        List<String> ls = new ArrayList<>(List.of("x", "y")); swapHelper(ls); System.out.println(ls);
        List<? extends Number> wl = li; Number n0 = wl.get(0); System.out.println(n0);
        List<? super Integer> sl = ln; Object o0 = sl.get(0); System.out.println(o0);
        Map<String, ? extends List<? extends Number>> mm = Map.of("k", li);
        for (Map.Entry<String, ? extends List<? extends Number>> e : mm.entrySet()) System.out.println(e.getKey() + e.getValue());
        Comparator<Object> cmp = (a, b) -> a.toString().compareTo(b.toString());
        List<String> sorted = new ArrayList<>(List.of("b", "a")); sorted.sort(cmp); System.out.println(sorted);
        Collections.sort(sorted, cmp);
        Function<? super String, ? extends Number> f = String::length;
        System.out.println(f.apply("abc"));
        Class<?> k = "s".getClass(); Class<? extends Number> k2 = Integer.valueOf(1).getClass(); System.out.println(k.getSimpleName() + k2.getSimpleName());
        Collection<? extends Object> co = ls; System.out.println(co.size());
        Supplier<? extends List<String>> sup = ArrayList::new; System.out.println(sup.get());
        List<? extends Comparable<?>> lc = List.of("a", 1); System.out.println(lc.size());
        Optional<? extends CharSequence> oc = Optional.of("hey"); System.out.println(oc.get().length());
        Set<Map.Entry<String, Integer>> es = new HashMap<String, Integer>(Map.of("a", 1)).entrySet();
        for (Map.Entry<String, ? extends Number> e : es) System.out.println(e.getValue());
        List<? extends Number>[] arr = new List[2]; arr[0] = li; System.out.println(arr[0]);
        System.out.println(Stream.of(1, 2, 3).map(i -> (Number) i).collect(Collectors.toList()));
        System.out.println(Arrays.asList(1, 2.5).get(1));
        List<? super Dog> sd = new ArrayList<Animal>(); sd.add(new Dog("q")); System.out.println(sd);
        Iterable<? extends Animal> ia = dogs; for (Animal an : ia) System.out.print(an); System.out.println();
    }
}
