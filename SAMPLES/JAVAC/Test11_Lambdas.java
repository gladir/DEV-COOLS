import java.util.*;
import java.util.function.*;
public class Test11_Lambdas {
    private final String tag = "T";
    private final Supplier<String> sup = () -> tag + this.tag.length();
    static final Map<String, Integer> TABLE = new HashMap<>();
    static { TABLE.put("one", 1); TABLE.put("two", 2); }
    private static final Comparator<String> BYLEN = (a, b) -> a.length() - b.length();
    class Counter {
        int c;
        Runnable inc = () -> c++;
        Supplier<Integer> get() { return () -> c + tag.length(); }
    }
    interface Visitor<R> { R num(int n); R add(Expr a, Expr b); }
    interface Expr { <R> R accept(Visitor<R> v); }
    static class Num implements Expr { int n; Num(int n) { this.n = n; } public <R> R accept(Visitor<R> v) { return v.num(n); } }
    static class Add implements Expr { Expr a, b; Add(Expr a, Expr b) { this.a = a; this.b = b; } public <R> R accept(Visitor<R> v) { return v.add(a, b); } }
    static int depth = 0;
    static void recurse() { depth++; recurse(); }
    public static void main(String[] args) {
        Test11_Lambdas g = new Test11_Lambdas();
        System.out.println(g.sup.get() + TABLE.get("two"));
        Counter ct = g.new Counter(); ct.inc.run(); ct.inc.run();
        System.out.println(ct.get().get());
        Expr e = new Add(new Num(3), new Add(new Num(4), new Num(5)));
        int val = e.accept(new Visitor<Integer>() {
            public Integer num(int n) { return n; }
            public Integer add(Expr a, Expr b) { return a.accept(this) + b.accept(this); }
        });
        String str = e.accept(new Visitor<String>() {
            public String num(int n) { return "" + n; }
            public String add(Expr a, Expr b) { return "(" + a.accept(this) + "+" + b.accept(this) + ")"; }
        });
        System.out.println(val + " " + str);
        List<Runnable> rs = new ArrayList<>();
        for (int i = 0; i < 3; i++) { int j = i * 10; rs.add(() -> System.out.print(j + " ")); }
        for (String s : new String[]{"p", "q"}) rs.add(() -> System.out.print(s + " "));
        rs.forEach(Runnable::run);
        System.out.println();
        int base = 100;
        Function<Integer, Supplier<Integer>> fm = x -> () -> x + base;
        System.out.println(fm.apply(5).get());
        Runnable outer = () -> {
            Runnable inner = new Runnable() { public void run() { System.out.println("anon in lambda " + base); } };
            inner.run();
        };
        outer.run();
        class Acc { int total; void add(int v) { total += v + base; } }
        Acc acc = new Acc(); acc.add(1); acc.add(2);
        System.out.println(acc.total);
        List<String> ws = new ArrayList<>(List.of("ccc", "a", "bb"));
        ws.sort(BYLEN);
        System.out.println(ws);
        try { recurse(); } catch (StackOverflowError so) { System.out.println("SO " + (depth > 1000)); }
        boolean assertOn = false;
        assert assertOn = true;
        System.out.println(assertOn);
        try { assert 1 > 2 : "never"; System.out.println("assert skipped"); } catch (AssertionError ae) { System.out.println("AE"); }
        Object o = 42;
        String d = o instanceof Integer i && i > 40 ? "big" : "small";
        System.out.println(d);
        if (!(o instanceof String s)) { System.out.println("not string"); } else { System.out.println(s.length()); }
        var list = new ArrayList<Map<String, int[]>>();
        list.add(Map.of("k", new int[]{1, 2}));
        for (var m : list) for (var en : m.entrySet()) System.out.println(en.getKey() + en.getValue()[1]);
        String tb = """
            {"a": "b\\n",
             "q": \"""x\"""}\s
            """;
        System.out.print(tb);
        System.out.println(tb.length());
    }
}
