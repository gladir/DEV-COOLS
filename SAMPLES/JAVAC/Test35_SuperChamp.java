public class Test35_SuperChamp {
    static class A { protected Object source = "a"; int n = 1; }
    static class B extends A {
        Object source = "b";
        void set(Object s) { super.source = s; this.source = "bb"; super.n += 5; }
        String show() { return super.source + "/" + source + "/" + super.n; }
    }
    public static void main(String[] args) { B b = new B(); b.set("x"); System.out.println(b.show()); }
}
