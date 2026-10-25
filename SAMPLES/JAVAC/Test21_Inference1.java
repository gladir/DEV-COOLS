import java.util.*;
import java.util.function.*;
import java.util.stream.*;

public class Test21_Inference1 {
    record Emp(String name, String dept, int age, double sal) {}
    public static void main(String[] args) {
        List<Emp> es = List.of(new Emp("a", "x", 30, 10), new Emp("b", "x", 40, 20), new Emp("c", "y", 25, 5), new Emp("d", "y", 35, 15));
        Map<String, Map<Boolean, List<String>>> m1 = es.stream().collect(
            Collectors.groupingBy(Emp::dept, TreeMap::new, Collectors.partitioningBy(e -> e.age() > 28, Collectors.mapping(Emp::name, Collectors.toList()))));
        System.out.println(m1);
        Map<String, Double> avg = es.stream().collect(Collectors.groupingBy(Emp::dept, Collectors.averagingDouble(Emp::sal)));
        System.out.println(new TreeMap<>(avg));
        Map<String, Optional<Emp>> oldest = es.stream().collect(Collectors.groupingBy(Emp::dept, Collectors.maxBy(Comparator.comparingInt(Emp::age))));
        oldest.entrySet().stream().sorted(Map.Entry.comparingByKey()).forEach(e -> System.out.println(e.getKey() + "=" + e.getValue().map(Emp::name).orElse("?")));
        Map<String, Long> cnt = es.stream().collect(Collectors.groupingBy(e -> e.dept(), Collectors.counting()));
        System.out.println(new TreeMap<>(cnt));
        Map<String, Integer> sums = es.stream().collect(Collectors.toMap(Emp::dept, Emp::age, Integer::sum, LinkedHashMap::new));
        System.out.println(sums);
        List<String> names = es.stream().sorted(Comparator.comparing(Emp::dept).thenComparing(Emp::sal, Comparator.reverseOrder())).map(Emp::name).collect(Collectors.toList());
        System.out.println(names);
        IntSummaryStatistics st = es.stream().mapToInt(Emp::age).summaryStatistics();
        System.out.println(st.getMax() + " " + st.getAverage());
        System.out.println(Stream.of("a,b", "c").flatMap(s -> Arrays.stream(s.split(","))).collect(Collectors.joining("|")));
        Map<Integer, List<String>> byLen = Stream.of("aa", "b", "cc", "ddd").collect(Collectors.groupingBy(String::length));
        System.out.println(byLen);
        Function<Integer, Function<Integer, Integer>> add = a -> b -> a + b;
        System.out.println(add.apply(3).apply(4));
        Supplier<Supplier<String>> ss = () -> () -> "nested";
        System.out.println(ss.get().get());
        BinaryOperator<Integer> mx = BinaryOperator.maxBy(Comparator.naturalOrder());
        System.out.println(mx.apply(3, 9));
        Optional<String> o = Optional.of("v").map(String::toUpperCase).filter(s -> !s.isEmpty());
        System.out.println(o.orElseGet(() -> "none"));
        var grouped = es.stream().collect(Collectors.groupingBy(Emp::dept, Collectors.collectingAndThen(Collectors.toList(), List::size)));
        System.out.println(new TreeMap<>(grouped));
        System.out.println(IntStream.rangeClosed(1, 5).boxed().collect(Collectors.reducing(0, (a, b) -> a + b)));
    }
}
