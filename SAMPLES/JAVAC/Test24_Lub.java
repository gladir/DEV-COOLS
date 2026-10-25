import java.util.*;
import java.util.function.*;
import java.util.stream.*;

public class Test24_Lub {
    enum Color { RED, GREEN, BLUE; Color next() { return values()[(ordinal() + 1) % values().length]; } }
    interface Animal { default String sound() { return "..."; } }
    static class Dog implements Animal { public String sound() { return "woof"; } }
    static class Cat implements Animal { public String sound() { return "meow"; } }
    static abstract class Shape<S extends Shape<S>> implements Comparable<S> {
        abstract double area();
        public int compareTo(S o) { return Double.compare(area(), o.area()); }
        @SuppressWarnings("unchecked") S self() { return (S) this; }
    }
    static class Circle extends Shape<Circle> { double r; Circle(double r) { this.r = r; } double area() { return 3 * r * r; } }
    static <E extends Enum<E>> E cycle(E e, E[] vals) { return vals[(e.ordinal() + 1) % vals.length]; }
    static <T> T pick(boolean b, T x, T y) { return b ? x : y; }
    static <T extends Comparable<? super T>> T maxArr(T[] a) { T m = a[0]; for (T t : a) if (t.compareTo(m) > 0) m = t; return m; }
    @SafeVarargs static <T> List<T> listOf(T... xs) { return new ArrayList<>(Arrays.asList(xs)); }
    static int sumAll(int... xs) { int s = 0; for (int x : xs) s += x; return s; }
    static String join(String sep, Object... xs) { return Arrays.stream(xs).map(String::valueOf).collect(Collectors.joining(sep)); }
    static class Box<T> { T v; Box(T v) { this.v = v; } <R> Box<R> map(Function<? super T, ? extends R> f) { return new Box<>(f.apply(v)); } T get() { return v; } }
    static class Counter { int c; void inc() { c++; } Supplier<Integer> asSupplier() { return this::next; } int next() { return ++c; } }
    static class Base { String who() { return "base"; } }
    static class Derived extends Base { String who() { return "derived"; } Supplier<String> sup() { return super::who; } }
    public static void main(String[] args) {
        System.out.println(Color.RED.next() + " " + cycle(Color.BLUE, Color.values()));
        EnumMap<Color, Integer> em = new EnumMap<>(Color.class);
        for (Color c : Color.values()) em.put(c, c.name().length());
        System.out.println(em);
        List<Animal> as = List.of(new Dog(), new Cat(), new Animal() {});
        System.out.println(as.stream().map(Animal::sound).collect(Collectors.joining(",")));
        System.out.println(new Circle(2).compareTo(new Circle(3)) + " " + Collections.max(List.of(new Circle(1), new Circle(5))).r);
        Animal pk = pick(true, new Dog(), new Cat());
        System.out.println(pk.sound());
        Comparable<?> cmp = pick(false, "s", 5);
        System.out.println(cmp);
        System.out.println(maxArr(new Integer[]{3, 7, 2}) + maxArr(new String[]{"a", "z"}));
        List<? extends Number> ln = listOf(1, 2.5);
        System.out.println(ln);
        System.out.println(sumAll() + sumAll(1) + sumAll(1, 2, 3) + join("-", 1, "a", 2.0));
        Box<String> b = new Box<>(5).map(i -> i * 2).map(Object::toString).map(s -> s + "!");
        System.out.println(b.get());
        Counter cn = new Counter(); Supplier<Integer> sp = cn.asSupplier(); sp.get(); sp.get();
        System.out.println(cn.c);
        System.out.println(new Derived().sup().get());
        IntFunction<int[]> mk = int[]::new;
        Function<Integer, List<String>> mkl = ArrayList::new;
        System.out.println(mk.apply(3).length + " " + mkl.apply(4).size());
        String[] sarr = Stream.of("b", "a").sorted().toArray(String[]::new);
        System.out.println(Arrays.toString(sarr));
        Map<String, Integer> m = new HashMap<>(Map.of("a", 1, "b", 2));
        m.replaceAll((k, v) -> v * 10);
        m.entrySet().removeIf(e -> e.getValue() > 15);
        System.out.println(m);
        List<Map.Entry<String, Integer>> es = new ArrayList<>(Map.of("x", 3, "y", 1).entrySet());
        es.sort(Map.Entry.comparingByValue());
        System.out.println(es.get(0).getKey());
        Object o = true ? 1 : "s";
        long l = true ? 1 : 2L;
        double d = false ? 1 : 2.5;
        System.out.println(o + " " + l + " " + d);
        Integer i1 = 127, i2 = 127; Long lg = 5L;
        System.out.println((i1 == i2) + " " + lg.equals(5L) + " " + (lg == 5));
        char ch = 'a'; ch += 1; ch++;
        byte by = 10; by *= 2;
        short sh = (short) 40000;
        System.out.println(ch + " " + by + " " + sh + " " + (char) (ch + 1) + (int) 'x');
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 3; i++) sb.append(i).append(i < 2 ? "," : "");
        System.out.println(sb.reverse());
        var list = new ArrayList<Map<String, List<Integer>>>();
        list.add(Map.of("k", List.of(1, 2)));
        for (var mm : list) for (var en : mm.entrySet()) System.out.println(en.getKey() + en.getValue().get(1));
        Iterator<Integer> it = new Iterator<>() { int c = 0; public boolean hasNext() { return c < 3; } public Integer next() { return c++; } };
        while (it.hasNext()) System.out.print(it.next());
        System.out.println();
        Optional<Integer> op = Optional.empty();
        System.out.println(op.or(() -> Optional.of(9)).get());
        UnaryOperator<String> up = String::toUpperCase;
        System.out.println(up.andThen(s -> s + "?").apply("q"));
    }
}
