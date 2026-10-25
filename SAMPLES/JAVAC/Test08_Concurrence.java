import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
public class Test08_Concurrence {
    enum Op {
        ADD("+") { int apply(int a, int b) { return a + b; } },
        MUL("*") { int apply(int a, int b) { return a * b; } };
        final String sym;
        Op(String s) { sym = s; }
        abstract int apply(int a, int b);
    }
    @FunctionalInterface interface Calc { int calc(int a, int b); }
    static <T extends Comparable<T>> T max(List<T> l) {
        T best = l.get(0);
        for (T t : l) if (t.compareTo(best) > 0) best = t;
        return best;
    }
    static int counter;
    static synchronized void inc() { counter++; }
    public static void main(String[] args) throws Exception {
        for (Op o : Op.values()) System.out.println(o + " " + o.sym + " " + o.apply(3, 4));
        Calc c = (a, b) -> a - b;
        System.out.println(c.calc(10, 3));
        System.out.println(max(Arrays.asList(3, 9, 2)) + " " + max(Arrays.asList("b", "zz", "a")));
        Thread[] ts = new Thread[4];
        for (int i = 0; i < ts.length; i++) {
            ts[i] = new Thread(() -> { for (int j = 0; j < 1000; j++) inc(); });
            ts[i].start();
        }
        for (Thread t : ts) t.join();
        System.out.println(counter);
        AtomicInteger ai = new AtomicInteger();
        ExecutorService ex = Executors.newFixedThreadPool(3);
        List<Future<Integer>> fs = new ArrayList<>();
        for (int i = 1; i <= 5; i++) { final int n = i; fs.add(ex.submit(() -> { ai.addAndGet(n); return n * n; })); }
        int total = 0;
        for (Future<Integer> f : fs) total += f.get();
        ex.shutdown();
        System.out.println(total + " " + ai.get());
        PriorityQueue<int[]> pq = new PriorityQueue<>((x, y) -> x[1] - y[1]);
        pq.add(new int[]{1, 5}); pq.add(new int[]{2, 1}); pq.add(new int[]{3, 3});
        while (!pq.isEmpty()) System.out.print(pq.poll()[0] + " ");
        System.out.println();
        Deque<Integer> dq = new ArrayDeque<>();
        dq.push(1); dq.addLast(2); dq.offerFirst(0);
        System.out.println(dq + " " + dq.peekLast());
        Map<String, List<String>> graph = new LinkedHashMap<>();
        graph.computeIfAbsent("a", k -> new ArrayList<>()).add("b");
        graph.computeIfAbsent("a", k -> new ArrayList<>()).add("c");
        graph.forEach((k, v) -> System.out.println(k + "->" + v));
        StringBuilder sb = new StringBuilder();
        for (char ch = 'a'; ch <= 'e'; ch++) sb.append(ch).append(ch - 'a');
        System.out.println(sb);
        String text = "the quick brown fox jumps over the lazy dog the end";
        Map<String, Integer> freq = new TreeMap<>();
        for (String w : text.split(" ")) freq.merge(w, 1, Integer::sum);
        System.out.println(freq);
        long start = System.nanoTime();
        System.out.println(start > 0);
        int[][] tri = new int[5][];
        for (int i = 0; i < 5; i++) { tri[i] = new int[i + 1]; tri[i][0] = tri[i][i] = 1; for (int j = 1; j < i; j++) tri[i][j] = tri[i-1][j-1] + tri[i-1][j]; }
        System.out.println(Arrays.deepToString(tri));
        Integer n1 = null;
        try { int z = n1; } catch (NullPointerException e) { System.out.println("NPE"); }
        System.out.println(Objects.hash(1, 2, 3) + " " + Objects.equals(null, null));
        char grade = 'B';
        switch (grade) { case 'A': case 'B': System.out.println("good"); case 'C': System.out.println("ok"); break; default: System.out.println("bad"); }
        double[] ds = {1.5, 2.5};
        double sum = 0; for (double dv : ds) sum += dv;
        System.out.printf("%.1f %s %d%n", sum, "x", 5L);
    }
}
