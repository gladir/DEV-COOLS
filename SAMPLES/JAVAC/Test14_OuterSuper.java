public class Test14_OuterSuper {
    String name;
    Test14_OuterSuper(String n) { name = n; }
    class Inner {
        String tag;
        Inner(String t) { tag = t; }
        String show() { return name + ":" + tag; }
    }
    static class Sub1 extends Test14_OuterSuper.Inner {
        Sub1(Test14_OuterSuper o, String t) { o.super(t + "!"); }
    }
    class Sub2 extends Inner {
        Sub2(Test14_OuterSuper other) { other.super("viaSub2"); }
    }
    static class Sub3 extends Inner {
        Sub3(Test14_OuterSuper o) { o.super("v" + o.name); }
        Sub3(String s) { this(new Test14_OuterSuper(s)); }
    }
    public static void main(String[] a) {
        Test14_OuterSuper x = new Test14_OuterSuper("X"), y = new Test14_OuterSuper("Y");
        System.out.println(new Sub1(x, "a").show());
        System.out.println(x.new Sub2(y).show());
        System.out.println(new Sub3("Q").show());
        try { new Sub1(null, "n"); } catch (NullPointerException e) { System.out.println("NPE"); }
    }
}
