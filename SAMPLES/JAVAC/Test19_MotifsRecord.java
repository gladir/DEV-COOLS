import java.util.*;
public class Test19_MotifsRecord {
    record Pair<A, B>(A a, B b) {}
    record Box<T>(T v) {}
    record Point(int x, int y) {}
    record Line(Point p, Point q) {}
    sealed interface Tree<T> permits Leaf, Node {}
    record Leaf<T>(T v) implements Tree<T> {}
    record Node<T>(Tree<T> l, Tree<T> r) implements Tree<T> {}
    static <T> int count(Tree<T> t) {
        return switch (t) {
            case Leaf<T> l -> 1;
            case Node<T>(Leaf<T> a, Leaf<T> b) -> 2;
            case Node<T>(Node<T> a, var b) -> count(a) + count(b);
            case Node<T>(Leaf<T> a, Node<T> b) -> 1 + count(b);
        };
    }
    static String f(Object o) {
        if (o instanceof Pair<?, ?>(Pair<?, ?>(var a, var b), Box<?>(String s)) && s.length() > 1) return "nested " + a + b + s;
        if (o instanceof Line(Point(var x1, var y1), Point(int x2, int y2)) && x1 == x2) return "vertical " + y1 + y2;
        if (o instanceof Line(Point p, var q)) return "line " + p + q;
        return switch (o) {
            case Point(int x, int y) when x == y -> "diag";
            case Point(int x, int y) -> "pt " + x + "," + y;
            case Box<?>(Box<?>(var inner)) -> "box2 " + inner;
            case Box<?>(var v) -> "box " + v;
            case null -> "null!";
            default -> "other";
        };
    }
    public static void main(String[] args) {
        System.out.println(f(new Pair<>(new Pair<>(1, 2), new Box<>("abc"))));
        System.out.println(f(new Line(new Point(1, 2), new Point(1, 5))));
        System.out.println(f(new Line(new Point(1, 2), new Point(3, 5))));
        System.out.println(f(new Point(2, 2)) + f(new Point(2, 3)) + f(new Box<>(new Box<>(7))) + f(new Box<>(8)) + f(null) + f("s"));
        Tree<Integer> t = new Node<>(new Node<>(new Leaf<>(1), new Leaf<>(2)), new Node<>(new Leaf<>(3), new Node<>(new Leaf<>(4), new Leaf<>(5))));
        System.out.println(count(t));
    }
}
