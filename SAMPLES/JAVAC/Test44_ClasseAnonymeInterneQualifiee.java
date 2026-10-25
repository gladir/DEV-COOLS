public class Test44_ClasseAnonymeInterneQualifiee {
    class Info { String s() { return "info"; } }
    static class Holder { String n = "h"; class Inner { String s() { return "inner" + n; } } }
    void run() {
        Holder h = new Holder();
        Holder.Inner i = h.new Inner() { String s() { return "anon-" + super.s(); } };
        System.out.println(i.s());
        for (int k = 0; k < 2; k++) {
            Info x = new Info() { int z = 3; { z++; } String s() { return "a" + z; } };
            if (k == 0) continue;
            System.out.println(x.s());
        }
    }
    public static void main(String[] args) { new Test44_ClasseAnonymeInterneQualifiee().run(); }
}
