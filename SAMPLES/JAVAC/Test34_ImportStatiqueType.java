import static javax.swing.UIDefaults.LazyValue;
import static java.util.Map.Entry;
import java.util.*;
public class Test34_ImportStatiqueType {
    public static void main(String[] args) {
        LazyValue v = t -> "lazy";
        Entry<String,Integer> e = Map.entry("a", 1);
        System.out.println(v.createValue(null) + " " + e);
    }
}
