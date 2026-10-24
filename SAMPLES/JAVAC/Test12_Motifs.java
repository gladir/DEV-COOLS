import java.util.*;
public class Test12_Motifs {
    sealed interface Shape permits Circle, Square, Rect {}
    record Circle(double r) implements Shape {}
    record Square(double side) implements Shape {}
    record Rect(double w, double h) implements Shape {}
    record Pair<A, B>(A a, B b) {}
    record Line(Pair<Integer, Integer> from, Pair<Integer, Integer> to) {}
    static double area(Shape s) {
        return switch (s) {
            case Circle c -> Math.PI * c.r() * c.r();
            case Square sq -> sq.side() * sq.side();
            case Rect(double w, double h) -> w * h;
        };
    }
    static String describe(Object o) {
        return switch (o) {
            case null -> "null!";
            case Integer i when i > 10 -> "big int " + i;
            case Integer i -> "int " + i;
            case String s when s.isEmpty() -> "empty string";
            case String s -> "string " + s.length();
            case int[] arr -> "int array " + arr.length;
            case Line(Pair<Integer, Integer>(var x1, var y1), Pair<Integer, Integer>(var x2, var y2)) -> "line " + (x2 - x1) + "," + (y2 - y1);
            case Pair<?, ?>(var a, var b) -> "pair " + a + b;
            default -> "other " + o;
        };
    }
    static void stmt(Object o) {
        switch (o) {
            case Character c -> System.out.println("char " + c);
            case Double d when d > 1 -> System.out.println("dbl>1");
            case Double d -> System.out.println("dbl");
            default -> System.out.println("dflt");
        }
    }
    enum Dir { N, S }
    static String dir(Dir d) { return switch (d) { case N -> "north"; case S -> "south"; }; }
    public static void main(String[] args) {
        System.out.printf("%.2f %.2f %.2f%n", area(new Circle(1)), area(new Square(2)), area(new Rect(2, 3)));
        for (Object o : new Object[]{null, 5, 50, "", "abc", new int[3], new Line(new Pair<>(1, 2), new Pair<>(4, 6)), new Pair<>("x", 'y'), 2.5})
            System.out.println(describe(o));
        stmt('c'); stmt(5.0); stmt(0.5); stmt("s");
        System.out.println(dir(Dir.S));
        Object obj = new Rect(2, 5);
        if (obj instanceof Rect(double w, double h) && w < h) System.out.println("narrow " + w + h);
        if (!(obj instanceof Rect(var w, var h))) System.out.println("no"); else System.out.println("yes " + w);
        if (obj instanceof Circle c) System.out.println(c); else System.out.println("not circle");
    }
}
