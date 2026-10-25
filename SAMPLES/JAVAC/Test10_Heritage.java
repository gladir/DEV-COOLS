import java.util.*;
import java.util.function.*;
import static java.lang.Math.*;
public class Test10_Heritage {
    static class A<T> { T val; void set(T t) { val = t; System.out.println("A.set " + t); } T get() { return val; } }
    static class B extends A<String> { @Override void set(String s) { super.set(s + "!"); } @Override String get() { return "B:" + super.get(); } }
    interface I1 { default String who() { return "I1"; } }
    interface I2 { default String who() { return "I2"; } }
    static class C implements I1, I2 { public String who() { return I1.super.who() + I2.super.who(); } }
    interface WithPriv { private int helper() { return 41; } default int val() { return helper() + 1; } static int sval() { return 7; } }
    static class Outer {
        private int secret = 5;
        class In1 { class In2 { int peek() { return secret * 2; } } }
        static class SN { int read(Outer o) { return o.secret; } }
        Runnable make() { return () -> { secret++; System.out.println("secret=" + secret + " " + this.getClass().getSimpleName()); }; }
    }
    static abstract class Shape { abstract double area(); Shape self() { return this; } }
    static void rethrow() throws Exception { try { throw new java.io.IOException("io"); } catch (Exception e) { throw e; } }
    @SuppressWarnings("finally")
    static int override() { try { return 1; } finally { return 2; } }
    static int nested() {
        int r = 0;
        try { try { throw new RuntimeException("inner"); } finally { r += 1; } }
        catch (RuntimeException e) { r += 10; }
        finally { r += 100; }
        return r;
    }
    public static void main(String[] args) throws Exception {
        A<String> a = new B(); a.set("x"); System.out.println(a.get());
        System.out.println(new C().who() + new WithPriv() {}.val() + WithPriv.sval());
        Outer o = new Outer();
        Outer.In1.In2 in2 = o.new In1().new In2();
        System.out.println(in2.peek() + " " + new Outer.SN().read(o));
        o.make().run();
        Shape sh = new Shape() { double area() { return 2.5; } };
        System.out.println(sh.self().area());
        try { rethrow(); } catch (Exception e) { System.out.println(e); }
        System.out.println(override() + " " + nested());
        System.out.println(max(3, 7) + " " + abs(-2) + " " + (int) sqrt(49) + " " + PI);
        Integer i1 = 1000, i2 = 1000; int i3 = 1000;
        System.out.println((i1 == i2) + " " + i1.equals(i2) + " " + (i1 == i3));
        Object[] objs = new String[]{"a"};
        try { objs[0] = 1; } catch (ArrayStoreException e) { System.out.println("ase"); }
        int[] src = {1, 2, 3}; int[] cp = src.clone(); cp[0] = 9;
        System.out.println(src[0] + " " + cp[0] + " " + src.getClass().getSimpleName());
        List<? extends Number> nums = List.of(1, 2.5, 3L);
        double s = 0; for (Number n : nums) s += n.doubleValue();
        System.out.println(s);
        Map<String, Function<Double, Double>> ops = new LinkedHashMap<>();
        ops.put("sq", x -> x * x); ops.put("neg", x -> -x);
        for (Map.Entry<String, Function<Double, Double>> e : ops.entrySet()) System.out.println(e.getKey() + e.getValue().apply(3.0));
        BinaryOperator<Integer> addb = Integer::sum;
        UnaryOperator<String> up = String::toUpperCase;
        System.out.println(addb.apply(2, 3) + up.apply("q"));
        boolean t = true; int tern = t ? 1 : 2; double dtern = t ? 1 : 2.0; Object otern = t ? 1 : "s";
        System.out.println(tern + " " + dtern + " " + otern + " " + (t ? 'a' : 0) + " " + (t ? null : 0));
        char cc = 'a'; cc += 1; cc++;
        System.out.println(cc + " " + (cc + 1) + " " + (char) (cc + 1) + " " + (int) cc);
        long big = Integer.MAX_VALUE; big++;
        System.out.println(big + " " + (Integer.MAX_VALUE + 1L) + " " + 5 / 2 * 2.0);
        StringBuilder sb = new StringBuilder(); for (String w : "a b c".split(" ")) sb.append(w.toUpperCase()).append("|");
        System.out.println(sb.length() + sb.toString());
    }
}
