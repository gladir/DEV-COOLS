import java.util.*;
import java.util.function.*;
public class Test03_Generiques {
    private int base = 10;
    class Inner {
        int v;
        Inner(int v) { this.v = v; }
        int sum() { return base + v; }
    }
    static class Node<T extends Comparable<T>> {
        T val; Node<T> left, right;
        Node(T v) { val = v; }
        void insert(T v) {
            if (v.compareTo(val) < 0) { if (left == null) left = new Node<>(v); else left.insert(v); }
            else { if (right == null) right = new Node<>(v); else right.insert(v); }
        }
        void walk(Consumer<T> c) {
            if (left != null) left.walk(c);
            c.accept(val);
            if (right != null) right.walk(c);
        }
    }
    interface Greeter { String greet(String n); }
    static class MyList implements Iterable<Integer> {
        int[] data = {5, 6, 7};
        public Iterator<Integer> iterator() {
            return new Iterator<Integer>() {
                int i = 0;
                public boolean hasNext() { return i < data.length; }
                public Integer next() { return data[i++]; }
            };
        }
    }
    static int sumAll(int... xs) { int s = 0; for (int x : xs) s += x; return s; }
    static <T> void printAll(List<? extends T> l) { for (T t : l) System.out.println(t); }
    public static void main(String[] args) {
        Test03_Generiques o = new Test03_Generiques();
        Test03_Generiques.Inner in = o.new Inner(5);
        System.out.println(in.sum());
        Node<Integer> root = new Node<>(5);
        for (int x : new int[]{3, 8, 1, 4, 9}) root.insert(x);
        StringBuilder sb = new StringBuilder();
        root.walk(x -> sb.append(x).append(','));
        System.out.println(sb);
        int k = 3;
        Greeter g = new Greeter() {
            public String greet(String n) { return "Hello " + n + k; }
        };
        System.out.println(g.greet("Bob"));
        class Local { int twice() { return k * 2; } }
        System.out.println(new Local().twice());
        for (int q : new MyList()) System.out.print(q + " ");
        System.out.println();
        System.out.println(sumAll() + " " + sumAll(1) + " " + sumAll(1, 2, 3));
        printAll(Arrays.asList("x", "y"));
        Function<Integer, Function<Integer, Integer>> add = a -> b -> a + b;
        System.out.println(add.apply(3).apply(4));
        Object obj = "str";
        if (obj instanceof String s && s.length() == 3) System.out.println("len3 " + s);
        Integer boxed = 127, boxed2 = 127;
        System.out.println(boxed == boxed2);
        boxed++;
        System.out.println(boxed);
        int[][] grid = new int[3][4];
        grid[1][2] = 7;
        int tot = 0;
        for (int[] row : grid) for (int c : row) tot += c;
        System.out.println(tot + " " + grid.length + " " + grid[0].length);
        String txt = """
            Hello
              World""";
        System.out.println(txt);
        BiFunction<Integer, Integer, Integer> mul = (a, b) -> a * b;
        System.out.println(mul.apply(6, 7));
        Supplier<List<String>> sup = ArrayList::new;
        List<String> ls = sup.get(); ls.add("z");
        System.out.println(ls);
        Optional<String> opt = Optional.of("abc");
        System.out.println(opt.map(String::toUpperCase).orElse("none"));
    }
}
