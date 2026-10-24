import java.util.*;
public class Test25_OuterGenerique {
    static class Outer<T> {
        T seed;
        Outer(T s) { seed = s; }
        class Inner { T val = seed; List<T> all = new ArrayList<>(); T get() { return val; } Inner add(T t) { all.add(t); return this; } }
        class Inner2 extends Inner { T extra; }
        Inner make() { return new Inner(); }
        static <U> Outer<U> of(U u) { return new Outer<>(u); }
        Inner2 make2() { Inner2 i = new Inner2(); i.extra = seed; return i; }
    }
    public static void main(String[] a) {
        Outer<String> o = new Outer<>("seed");
        Outer<String>.Inner in = o.make();
        String s = in.get();
        String v = in.val;
        List<String> l = in.add("x").all;
        Outer<Integer>.Inner n = Outer.of(5).new Inner();
        int k = n.val + 1;
        var in2 = o.make2();
        String e = in2.extra;
        String g = in2.get();
        Outer<String>.Inner viaNew = o.new Inner();
        System.out.println(s + v + l + k + e + g + viaNew.val);
        System.out.println(in.getClass().getName());
    }
}
