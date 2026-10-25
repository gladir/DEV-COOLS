public class Test06_Init {
    static class Base {
        static { System.out.println("Base static"); }
        { System.out.println("Base inst"); }
        int x = init("Base.x");
        Base() { System.out.println("Base ctor"); show(); }
        void show() { System.out.println("Base show"); }
        static int init(String s) { System.out.println(s); return 1; }
    }
    static class Derived extends Base {
        static { System.out.println("Derived static"); }
        int y = init("Derived.y");
        { System.out.println("Derived inst"); }
        Derived() { super(); System.out.println("Derived ctor " + y); }
        void show() { System.out.println("Derived show " + y); }
    }
    static void over(int x) { System.out.println("int"); }
    static void over(long x) { System.out.println("long"); }
    static void over(Integer x) { System.out.println("Integer"); }
    static void over(Object x) { System.out.println("Object"); }
    static void over(int... x) { System.out.println("varargs"); }
    static int f() { int i = 0; try { i = 1; throw new RuntimeException("x"); } catch (RuntimeException e) { i = 2; return i; } finally { i = 3; System.out.println("fin " + i); } }
    static void g() {
        outer:
        for (int i = 0; i < 3; i++) {
            try {
                if (i == 1) continue;
                if (i == 2) break outer;
                System.out.println("body " + i);
            } finally {
                System.out.println("cleanup " + i);
            }
        }
    }
    public static void main(String[] args) {
        new Derived();
        over(1); over(1L); over((short) 1); over(Integer.valueOf(1)); over("s"); over(); over(1, 2);
        System.out.println(f());
        g();
        String s = null;
        System.out.println("null concat " + s);
        Object o = new int[]{1,2};
        System.out.println(o instanceof int[]);
        int[] a = null;
        try { System.out.println(a[0]); } catch (NullPointerException e) { System.out.println("npe"); }
        try { System.out.println(1 / (a == null ? 0 : 1)); } catch (ArithmeticException e) { System.out.println(e.getMessage()); }
        int x = 5;
        x = x++ * 2 + x--;
        System.out.println(x);
        System.out.println(010 == 8 ? "oct" : "no");
        throw new IllegalStateException("boom");
    }
}
