import java.util.*;
import java.util.function.*;
import java.util.stream.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public class Test23_Intersection {
    static class LinkedStack<T> implements Iterable<T> {
        class Node { T val; Node next; Node(T v, Node n) { val = v; next = n; } }
        Node head; int size;
        void push(T v) { head = new Node(v, head); size++; }
        T pop() { T v = head.val; head = head.next; size--; return v; }
        public Iterator<T> iterator() {
            return new Iterator<T>() {
                Node cur = head;
                public boolean hasNext() { return cur != null; }
                public T next() { T v = cur.val; cur = cur.next; return v; }
            };
        }
    }
    static class Pair<A, B> {
        final A a; final B b;
        Pair(A a, B b) { this.a = a; this.b = b; }
        <C> Pair<A, C> withB(C c) { return new Pair<>(a, c); }
        static <X, Y> Pair<X, Y> of(X x, Y y) { return new Pair<>(x, y); }
        public String toString() { return "(" + a + "," + b + ")"; }
    }
    interface Visitor<R> { R visitNum(int n); R visitAdd(Expr l, Expr r); }
    interface Expr { <R> R accept(Visitor<R> v); }
    static Expr num(int n) { return new Expr() { public <R> R accept(Visitor<R> v) { return v.visitNum(n); } }; }
    static Expr add(Expr l, Expr r) { return new Expr() { public <R> R accept(Visitor<R> v) { return v.visitAdd(l, r); } }; }
    static <T, R> List<R> mapAll(Collection<? extends T> c, Function<? super T, ? extends R> f) {
        List<R> out = new ArrayList<>();
        for (T t : c) out.add(f.apply(t));
        return out;
    }
    static <T> Predicate<T> not(Predicate<? super T> p) { return t -> !p.test(t); }
    static <T extends Comparable<T>> Optional<T> maxOpt(Stream<T> s) { return s.max(Comparator.naturalOrder()); }
    static void run(Runnable r) { System.out.println("runnable"); r.run(); }
    static <T> T run(Callable<T> c) throws Exception { System.out.println("callable"); return c.call(); }
    static void over(Function<String, Integer> f) { System.out.println("func " + f.apply("abc")); }
    static void over(Supplier<Integer> s) { System.out.println("supp " + s.get()); }
    public static void main(String[] args) throws Exception {
        LinkedStack<String> st = new LinkedStack<>();
        st.push("a"); st.push("b"); st.push("c");
        for (String s : st) System.out.print(s);
        System.out.println(" " + st.pop() + st.size);
        LinkedStack<String>.Node n = st.head;
        String v = n.val;
        System.out.println(v);
        Pair<String, Integer> p = Pair.of("x", 1);
        Pair<String, List<Integer>> p2 = p.withB(List.of(1, 2));
        System.out.println(p2 + " " + p2.b.get(1));
        Expr e = add(num(1), add(num(2), num(3)));
        int total = e.accept(new Visitor<Integer>() {
            public Integer visitNum(int n) { return n; }
            public Integer visitAdd(Expr l, Expr r) { return l.accept(this) + r.accept(this); }
        });
        String shown = e.accept(new Visitor<String>() {
            public String visitNum(int n) { return "" + n; }
            public String visitAdd(Expr l, Expr r) { return "(" + l.accept(this) + "+" + r.accept(this) + ")"; }
        });
        System.out.println(total + " " + shown);
        System.out.println(mapAll(List.of(1, 2, 3), x -> "n" + x));
        System.out.println(Stream.of("a", "", "b").filter(not(String::isEmpty)).collect(Collectors.toList()));
        System.out.println(maxOpt(Stream.of(3, 8, 1)).get());
        run(() -> System.out.println("hi"));
        System.out.println(run(() -> 42));
        over(s -> s.length());
        over(() -> 7);
        Map<String, List<Integer>> multi = new TreeMap<>();
        multi.computeIfAbsent("k", k -> new ArrayList<>()).add(5);
        multi.merge("k", List.of(6), (l1, l2) -> { List<Integer> r = new ArrayList<>(l1); r.addAll(l2); return r; });
        System.out.println(multi);
        List<int[]> arrs = new ArrayList<>(); arrs.add(new int[]{1, 2});
        System.out.println(arrs.stream().mapToInt(a -> a[0] + a[1]).sum());
        ConcurrentHashMap<String, LongAdder> counts = new ConcurrentHashMap<>();
        for (String w : "a b a c a".split(" ")) counts.computeIfAbsent(w, k -> new LongAdder()).increment();
        System.out.println(new TreeMap<>(counts));
        Function<Integer, Function<Integer, Function<Integer, Integer>>> f3 = a -> b -> c -> a * b + c;
        System.out.println(f3.apply(2).apply(3).apply(4));
        Optional<Optional<String>> oo = Optional.of(Optional.of("deep"));
        System.out.println(oo.flatMap(Function.identity()).get());
        System.out.println(Stream.iterate(1, x -> x * 2).limit(6).map(String::valueOf).collect(Collectors.joining(",", "[", "]")));
        double avg = IntStream.of(1, 2, 3, 4).average().orElse(0);
        System.out.println(avg);
        List<List<Integer>> nested = List.of(List.of(1, 2), List.of(3), List.of());
        System.out.println(nested.stream().flatMap(List::stream).map(x -> x * x).reduce(0, Integer::sum));
        System.out.println(nested.stream().mapToInt(List::size).boxed().collect(Collectors.toList()));
        BiFunction<String, Integer, String> rep = String::repeat;
        System.out.println(rep.andThen(String::toUpperCase).apply("ab", 2));
        Comparator<String> byLen = Comparator.comparingInt(String::length);
        System.out.println(Stream.of("ccc", "a", "bb").sorted(byLen.reversed().thenComparing(Comparator.naturalOrder())).toList());
        PriorityQueue<Pair<String, Integer>> pq = new PriorityQueue<>((x, y) -> y.b - x.b);
        pq.add(Pair.of("lo", 1)); pq.add(Pair.of("hi", 9));
        System.out.println(pq.poll());
    }
}
