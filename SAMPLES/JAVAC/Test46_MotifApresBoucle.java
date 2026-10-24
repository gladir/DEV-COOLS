public class Test46_MotifApresBoucle {
    static int f(Object o) {
        Object p = o;
        while (!(p instanceof String s)) { p = p.toString(); }
        return s.length();
    }
    static int g(Object o) {
        if (!(o instanceof Integer i)) { return -1; }
        return i + 1;
    }
    public static void main(String[] args) { System.out.println(f(5) + g(4) + g("x")); }
}
