import java.io.*;
import java.util.*;
public class Serial1 {
    static class Base { int baseVal = 5; Base() { baseVal = 11; } }
    static class P extends Base implements Serializable {
        String name; int age; transient int skip = 9; static int st = 3; double[] ds; P friend; long big = 1L << 40; char c = 'x'; boolean flag = true; byte b = -3; short sh = 7; float fl = 2.5f;
        P(String n, int a) { name = n; age = a; ds = new double[]{1.5, 2.5}; }
    }
    static class V implements Serializable { private static final long serialVersionUID = 42L; int x = 1; String[][] grid = {{"a", "b"}, {"c"}}; Object o = "obj"; }
    static class Cust implements Serializable {
        int a = 3; transient int t = 5; String s = "custom";
        private void writeObject(ObjectOutputStream o) throws IOException { o.defaultWriteObject(); o.writeInt(t * 2); o.writeUTF("extra"); }
        private void readObject(ObjectInputStream i) throws IOException, ClassNotFoundException { i.defaultReadObject(); t = i.readInt(); System.out.println("readObject extra=" + i.readUTF()); }
    }
    static class Ext implements Externalizable {
        int v = 7; String w = "ext";
        public Ext() { System.out.println("Ext()"); }
        public void writeExternal(ObjectOutput o) throws IOException { o.writeInt(v); o.writeUTF(w); }
        public void readExternal(ObjectInput i) throws IOException { v = i.readInt(); w = i.readUTF(); }
    }
    static class Single implements Serializable { static final Single INSTANCE = new Single(); private Object readResolve() { return INSTANCE; } }
    enum Color { RED, GREEN { int f() { return 1; } }; int f() { return 0; } }
    record Pt(int x, String y) implements Serializable {}
    static byte[] ser(Object... os) throws Exception {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ObjectOutputStream oo = new ObjectOutputStream(bo)) { for (Object o : os) oo.writeObject(o); oo.writeInt(77); oo.writeUTF("tail"); }
        return bo.toByteArray();
    }
    static String hex(byte[] b) { StringBuilder sb = new StringBuilder(); for (byte x : b) sb.append(String.format("%02x", x)); return sb.toString(); }
    public static void main(String[] args) throws Exception {
        System.out.println(ObjectStreamClass.lookup(P.class).getSerialVersionUID() + " " + ObjectStreamClass.lookup(Cust.class).getSerialVersionUID() + " " + ObjectStreamClass.lookup(Pt.class).getSerialVersionUID() + " " + ObjectStreamClass.lookup(int[].class).getSerialVersionUID() + " " + ObjectStreamClass.lookup(String[].class).getSerialVersionUID() + " " + ObjectStreamClass.lookup(Color.class).getSerialVersionUID());
        P p = new P("ann", 30); P q = new P("bob", 31); p.friend = q; q.friend = p; p.skip = 100; P.st = 50;
        Object[] objs = {p, new V(), new Cust(), new Ext(), Single.INSTANCE, Color.GREEN, Color.RED, new Pt(3, "z"), new int[]{1, 2, 3}, "str", "str", null, new String[]{"a", null}, Color.class, new boolean[]{true, false}, new long[]{5}, new char[]{'h', 'i'}};
        byte[] data = ser(objs);
        System.out.println(data.length + " " + hex(data));
        try (ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(data))) {
            P p2 = (P) oi.readObject();
            System.out.println(p2.name + p2.age + " " + p2.skip + " " + P.st + " " + p2.baseVal + " " + p2.friend.name + " " + (p2.friend.friend == p2) + " " + Arrays.toString(p2.ds) + " " + p2.big + p2.c + p2.flag + p2.b + p2.sh + p2.fl);
            V v = (V) oi.readObject(); System.out.println(v.x + Arrays.deepToString(v.grid) + v.o);
            Cust c = (Cust) oi.readObject(); System.out.println(c.a + " " + c.t + " " + c.s);
            Ext e = (Ext) oi.readObject(); System.out.println(e.v + e.w);
            System.out.println(oi.readObject() == Single.INSTANCE);
            System.out.println(oi.readObject() + " " + (oi.readObject() == Color.RED));
            System.out.println(oi.readObject());
            System.out.println(Arrays.toString((int[]) oi.readObject()));
            String s1 = (String) oi.readObject(), s2 = (String) oi.readObject(); System.out.println(s1 + (s1 == s2));
            System.out.println(oi.readObject() + " " + Arrays.toString((String[]) oi.readObject()) + " " + oi.readObject());
            System.out.println(Arrays.toString((boolean[]) oi.readObject()) + Arrays.toString((long[]) oi.readObject()) + new String((char[]) oi.readObject()));
            System.out.println(oi.readInt() + oi.readUTF());
            try { oi.readObject(); } catch (EOFException ex) { System.out.println("EOF"); }
        }
        try { ser(new Object()); } catch (NotSerializableException ex) { System.out.println("NSE " + ex.getMessage()); }
        class L implements Serializable { Object o = new Object(); }
        try { ser(new L()); } catch (NotSerializableException ex) { System.out.println("NSE " + ex.getMessage()); }
        // unshared / reset
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        ObjectOutputStream oo = new ObjectOutputStream(bo);
        String sh = "shared"; oo.writeObject(sh); oo.writeObject(sh); oo.reset(); oo.writeObject(sh); oo.writeUnshared(sh); oo.flush();
        System.out.println(hex(bo.toByteArray()));
        ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(bo.toByteArray()));
        System.out.println(oi.readObject() + " " + oi.readObject() + " " + oi.readObject() + " " + oi.readObject());
    }
}
