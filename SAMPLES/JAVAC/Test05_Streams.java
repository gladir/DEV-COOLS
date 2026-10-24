import java.util.*;
import java.util.stream.*;
public class Test05_Streams {
    static class P implements Comparable<P> {
        String name; int age;
        P(String n, int a) { name = n; age = a; }
        public int compareTo(P o) { return Integer.compare(age, o.age); }
        public String toString() { return name + ":" + age; }
        String getName() { return name; }
        int getAge() { return age; }
    }
    interface Stack2<T> { void push(T t); T pop(); boolean isEmpty(); static <T> Stack2<T> create() { return new ArrStack<>(); } }
    static class ArrStack<T> implements Stack2<T> {
        private List<T> items = new ArrayList<>();
        public void push(T t) { items.add(t); }
        public T pop() { return items.remove(items.size() - 1); }
        public boolean isEmpty() { return items.isEmpty(); }
    }
    public static void main(String[] args) {
        List<P> ps = new ArrayList<>(List.of(new P("Ann", 30), new P("Bob", 25), new P("Cy", 35)));
        Collections.sort(ps);
        System.out.println(ps);
        ps.sort(Comparator.comparing(P::getName).reversed());
        System.out.println(ps);
        System.out.println(ps.stream().filter(p -> p.age > 26).map(P::getName).collect(Collectors.joining(",")));
        System.out.println(ps.stream().mapToInt(P::getAge).sum());
        Map<Boolean, List<String>> parts = ps.stream().collect(Collectors.partitioningBy(p -> p.age >= 30, Collectors.mapping(P::getName, Collectors.toList())));
        System.out.println(parts);
        Map<Integer, Long> byDecade = ps.stream().collect(Collectors.groupingBy(p -> p.age / 10, Collectors.counting()));
        System.out.println(byDecade);
        System.out.println(IntStream.rangeClosed(1, 5).map(x -> x * x).boxed().collect(Collectors.toList()));
        System.out.println(Stream.of("a", "bb", "ccc").collect(Collectors.toMap(s -> s, String::length)));
        double avg = ps.stream().mapToInt(p -> p.age).average().orElse(0);
        System.out.println(avg);
        Stack2<String> st = Stack2.create();
        st.push("a"); st.push("b");
        while (!st.isEmpty()) System.out.println(st.pop());
        P[] arr = ps.toArray(new P[0]);
        Arrays.sort(arr, (x, y) -> x.age - y.age);
        System.out.println(Arrays.toString(arr));
        var m = new TreeMap<String, List<Integer>>();
        m.computeIfAbsent("k", k -> new ArrayList<>()).add(4);
        m.computeIfAbsent("k", k -> new ArrayList<>()).add(5);
        for (var e : m.entrySet()) System.out.println(e.getKey() + "=" + e.getValue());
        String joined = String.join("-", List.of("x", "y", "z"));
        System.out.println(joined);
        Iterator<P> it = ps.iterator();
        while (it.hasNext()) if (it.next().age < 30) it.remove();
        System.out.println(ps.size());
        int day = 3;
        String name = switch (day) { case 1, 7 -> "weekend"; case 2, 3, 4, 5, 6 -> { String t = "week"; yield t + "day"; } default -> "?"; };
        System.out.println(name);
        long cnt = "hello world".chars().filter(ch -> ch == 'o').count();
        System.out.println(cnt);
    }
}
