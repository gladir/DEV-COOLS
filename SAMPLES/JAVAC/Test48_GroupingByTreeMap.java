import java.util.*;
import java.util.function.*;
import java.util.stream.*;
public class Test48_GroupingByTreeMap {
    record FP(int v, String n) {}
    public static void main(String[] args) {
        Stream.of(new FP(1, "a"), new FP(1, "b"), new FP(2, "c"))
              .collect(Collectors.groupingBy(FP::v, TreeMap::new,
                       Collectors.toMap(FP::n, Function.identity(), (x, y) -> x)))
              .forEach((version, entries) -> { if (version == 1) System.out.println(entries.size()); });
    }
}
