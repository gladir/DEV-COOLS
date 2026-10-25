import java.io.*;
import java.util.*;
import java.util.function.*;
public class Serial9 {
    interface SF extends Function<Integer, Integer>, Serializable {}
    static int twice(int x) { return 2 * x; }
    public static void main(String[] a) throws Exception {
        int k = 7; String s = "cap";
        SF f = x -> x * k;
        SF g = Serial9::twice;
        Supplier<String> sup = (Supplier<String> & Serializable) () -> s + k;
        Comparator<String> c = (Comparator<String> & Serializable) String::compareTo;
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ObjectOutputStream oo = new ObjectOutputStream(bo)) { oo.writeObject(f); oo.writeObject(g); oo.writeObject(sup); oo.writeObject(c); }
        try (ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(bo.toByteArray()))) {
            SF f2 = (SF) oi.readObject(); SF g2 = (SF) oi.readObject();
            System.out.println(f2.apply(3) + " " + g2.apply(4) + " " + ((Supplier<String>) oi.readObject()).get() + " " + ((Comparator<String>) oi.readObject()).compare("a", "b"));
        }
        System.out.println(bo.size());
    }
}
