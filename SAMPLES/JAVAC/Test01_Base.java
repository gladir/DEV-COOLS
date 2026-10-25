import java.util.*;
public class Test01_Base {
    interface Shape { double area(); default String name() { return "shape"; } }
    static class Circle implements Shape {
        double r;
        Circle(double r) { this.r = r; }
        public double area() { return Math.PI * r * r; }
        public String name() { return "circle"; }
    }
    static class Rect implements Shape {
        double w, h;
        Rect(double w, double h) { this.w = w; this.h = h; }
        public double area() { return w * h; }
    }
    static int fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
    public static void main(String[] args) {
        List<String> names = new ArrayList<>();
        names.add("a"); names.add("b"); names.add("c");
        for (String s : names) System.out.println(s + 1);
        int[] arr = {1, 2, 3};
        long sum = 0;
        for (int x : arr) sum += x;
        System.out.println("sum=" + sum);
        Map<String, Integer> m = new HashMap<>();
        m.put("x", 5);
        int v = m.get("x");
        System.out.println(v);
        Shape sh = new Circle(2.0);
        System.out.println(sh.name() + " " + sh.area());
        Shape r2 = new Rect(3, 4);
        System.out.println(r2.name() + " " + r2.area());
        Runnable r = () -> System.out.println("hi " + v);
        r.run();
        names.forEach(n -> System.out.println(n));
        names.stream().map(String::length).forEach(System.out::println);
        String t = switch (v) { case 5 -> "five"; default -> "other"; };
        System.out.println(t);
        char ch = 'a'; ch += 1;
        byte b = 10; b++;
        System.out.println(fib(10) + t + ch + b);
        Comparator<String> c = Comparator.comparing(String::length);
        names.sort(c.reversed());
        System.out.println(names);
    }
}
