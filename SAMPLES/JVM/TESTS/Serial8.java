import java.io.*;
import java.util.*;
public class Serial8 {
    static class NoCtor { int x; NoCtor(int x) { this.x = x; } }
    static class Sub extends NoCtor implements Serializable { Sub() { super(1); } }
    static class Holder implements Serializable { Object o = new Object(); }
    static class Vers implements Serializable { private static final long serialVersionUID = 1L; int a = 5; }
    static class Pf implements Serializable {
        private static final ObjectStreamField[] serialPersistentFields = { new ObjectStreamField("n", int.class), new ObjectStreamField("s", String.class) };
        transient int real = 3; transient String str = "x";
        private void writeObject(ObjectOutputStream o) throws IOException { ObjectOutputStream.PutField f = o.putFields(); f.put("n", real * 2); f.put("s", str + "!"); o.writeFields(); }
        private void readObject(ObjectInputStream i) throws IOException, ClassNotFoundException { ObjectInputStream.GetField f = i.readFields(); real = f.get("n", 0); str = (String) f.get("s", "?"); }
    }
    static class Node implements Serializable { String name; List<Node> kids = new ArrayList<>(); Node parent; Node(String n) { name = n; } }
    static class Ver implements Serializable { int a = 1; transient Thread t = null; private void readObject(ObjectInputStream i) throws IOException, ClassNotFoundException { i.defaultReadObject(); if (a < 0) throw new InvalidObjectException("neg"); } }
    static byte[] ser(Object o) throws Exception { ByteArrayOutputStream bo = new ByteArrayOutputStream(); try (ObjectOutputStream oo = new ObjectOutputStream(bo)) { oo.writeObject(o); } return bo.toByteArray(); }
    static Object des(byte[] b) throws Exception { try (ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(b))) { return oi.readObject(); } }
    static String hex(byte[] b) { StringBuilder sb = new StringBuilder(); for (byte x : b) sb.append(String.format("%02x", x)); return sb.toString(); }
    public static void main(String[] args) throws Exception {
        try { des(ser(new Sub())); } catch (Exception e) { System.out.println(e); }
        try { ser(new Holder()); } catch (Exception e) { System.out.println(e); }
        byte[] b = ser(new Vers());
        byte[] c = b.clone(); // modifier le SUID
        for (int i = 0; i < c.length - 8; i++) if (c[i] == 0 && c[i + 1] == 0 && c[i + 7] == 1 && c[i + 8] == 2) { c[i + 7] = 9; break; }
        try { des(c); System.out.println("no error"); } catch (Exception e) { System.out.println(e); }
        try { des(new byte[]{1, 2, 3, 4}); } catch (Exception e) { System.out.println(e); }
        try { des(new byte[]{(byte) 0xac, (byte) 0xed, 0, 5}); } catch (Exception e) { System.out.println(e); }
        try { des(Arrays.copyOf(b, b.length - 3)); } catch (Exception e) { System.out.println(e); }
        Pf p = (Pf) des(ser(new Pf())); System.out.println(p.real + p.str + hex(ser(new Pf())).length());
        Node root = new Node("r"); Node k = new Node("k"); k.parent = root; root.kids.add(k); Node r2 = (Node) des(ser(root)); System.out.println(r2.kids.get(0).parent == r2);
        System.out.println(((Ver) des(ser(new Ver()))).a);
        ObjectOutputStream oo = new ObjectOutputStream(new ByteArrayOutputStream());
        try { oo.writeObject(new Holder()); } catch (NotSerializableException e) { System.out.println("NSE " + e.getMessage()); }
        // custom data stream mixing
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ObjectOutputStream o2 = new ObjectOutputStream(bo)) { o2.writeInt(1); o2.writeObject("s"); o2.writeDouble(2.5); o2.writeObject(List.of(1)); o2.writeUTF("end"); o2.write(new byte[]{1, 2, 3}); }
        System.out.println(hex(bo.toByteArray()));
        try (ObjectInputStream i2 = new ObjectInputStream(new ByteArrayInputStream(bo.toByteArray()))) {
            System.out.println(i2.readInt() + i2.readObject().toString() + i2.readDouble() + i2.readObject() + i2.readUTF() + i2.read() + i2.available());
            try { i2.readObject(); } catch (OptionalDataException e) { System.out.println("ODE " + e.length + " " + e.eof); }
        }
        ObjectInputStream i3 = new ObjectInputStream(new ByteArrayInputStream(ser("x")));
        System.out.println(i3.readObject()); try { i3.readObject(); } catch (EOFException e) { System.out.println("EOF"); }
        System.out.println(ObjectStreamClass.lookup(Pf.class).getFields().length + " " + ObjectStreamClass.lookup(Holder.class).getName() + " " + ObjectStreamClass.lookup(Object.class));
    }
}
