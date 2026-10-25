import java.util.*;
import java.util.stream.*;
public class Test47_LubClasses {
    interface MM {} interface GC extends MM {} interface GC2 extends GC {}
    static Set<Class<? extends MM>> f() {
        return Stream.of(MM.class, GC.class, GC2.class).collect(Collectors.toSet());
    }
    static void g(int v, Object e) {}
    public static void main(String[] args) {
        System.out.println(f().size());
        Map<Integer, List<String>> m = Stream.of("a", "bb").collect(Collectors.groupingBy(String::length));
        m.forEach((version, entries) -> { if (version == 1) g(version, entries); });
    }
}
