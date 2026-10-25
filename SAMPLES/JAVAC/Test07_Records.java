import java.util.*;
public class Test07_Records {
    record Point(int x, int y) {
        Point { if (x < 0) throw new IllegalArgumentException("neg"); }
        double dist() { return Math.sqrt(x * x + y * y); }
        static Point origin() { return new Point(0, 0); }
    }
    record Pair<A, B>(A first, B second) {}
    record Person(String name, double score, long id, boolean ok) {}
    interface Visitor<R> { R visit(int n); }
    public static void main(String[] args) {
        Point p = new Point(3, 4);
        System.out.println(p + " " + p.x() + " " + p.dist() + " " + Point.origin());
        System.out.println(p.equals(new Point(3, 4)) + " " + p.equals(new Point(3, 5)) + " " + (p.hashCode() == new Point(3, 4).hashCode()));
        Pair<String, Integer> pr = new Pair<>("a", 1);
        System.out.println(pr + " " + pr.first() + pr.second());
        Person pe = new Person("Zed", 1.5, 99L, true);
        System.out.println(pe + " " + pe.hashCode() + " " + pe.equals(new Person("Zed", 1.5, 99L, true)));
        try { new Point(-1, 0); } catch (IllegalArgumentException e) { System.out.println(e.getMessage()); }
        Set<Point> set = new HashSet<>(); set.add(p); set.add(new Point(3, 4));
        System.out.println(set.size());
    }
}
