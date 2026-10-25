import java.util.*;
import java.util.function.*;
public class Test20_NonNomme {
    record Point(int x, int y) {}
    record Line(Point a, Point b) {}
    static int f(Object o) {
        return switch (o) {
            case Point(int x, _) -> x;
            case Line(Point(var x1, _), _) -> x1 * 10;
            case String _ -> -1;
            default -> 0;
        };
    }
    public static void main(String[] args) {
        int _ = 5;
        int _ = 6;
        List<Integer> l = List.of(1, 2, 3);
        int n = 0;
        for (var _ : l) n++;
        try { Integer.parseInt("x"); } catch (NumberFormatException _) { n += 10; }
        BiFunction<Integer, Integer, Integer> bf = (_, b) -> b * 2;
        Function<Integer, String> fn = _ -> "const";
        Object o = new Point(3, 4);
        if (o instanceof Point(var px, _)) n += px;
        System.out.println(n + " " + bf.apply(1, 5) + fn.apply(9) + f(new Point(7, 8)) + f(new Line(new Point(2, 3), new Point(4, 5))) + f("s") + f(1));
    }
}
