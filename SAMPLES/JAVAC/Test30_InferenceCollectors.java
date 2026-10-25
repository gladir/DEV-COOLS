import java.util.*;
import java.util.stream.*;
public class Test30_InferenceCollectors {
    public static void main(String[] args) {
        List<Object> l = Stream.of("a").collect(Collectors.toList());
        List<Number> m = Stream.of(1, 2).collect(Collectors.toList());
        Set<Object> s = Stream.of("a").collect(Collectors.toSet());
        Map<Object, List<Object>> g = Stream.of("a").collect(Collectors.groupingBy(x -> x));
        List<Object> n = Stream.of("a").toList() instanceof List<String> q ? new ArrayList<>(q) : null;
        System.out.println(l + " " + m + s + g);
    }
}
