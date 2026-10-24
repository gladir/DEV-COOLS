import java.io.*;
import java.math.*;
import java.util.*;
public class Serial5 {
    static String hex(byte[] b) { StringBuilder sb = new StringBuilder(); for (byte x : b) sb.append(String.format("%02x", x)); return sb.toString(); }
    static void t(String n, Object o) throws Exception {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ObjectOutputStream oo = new ObjectOutputStream(bo)) { oo.writeObject(o); }
        Object r;
        try (ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(bo.toByteArray()))) { r = oi.readObject(); }
        System.out.println(n + " " + bo.size() + " " + r + " " + (o instanceof Collection || o instanceof Map ? "" : "") + hex(bo.toByteArray()).hashCode());
        System.out.println("   " + hex(bo.toByteArray()));
    }
    public static void main(String[] args) throws Exception {
        t("Integer", 42); t("Long", 5L); t("Double", 2.5); t("Boolean", true); t("Char", 'c'); t("Short", (short) 3); t("Byte", (byte) 4); t("Float", 1.5f);
        t("String", "hello");
        t("ArrayList", new ArrayList<>(List.of("a", "b", "c")));
        t("LinkedList", new LinkedList<>(List.of(1, 2)));
        t("HashMap", new HashMap<>(Map.of("k", 1)));
        t("LinkedHashMap", new LinkedHashMap<>(Map.of("k", 1)));
        t("TreeMap", new TreeMap<>(Map.of("k", 1, "j", 2)));
        t("HashSet", new HashSet<>(List.of("x")));
        t("TreeSet", new TreeSet<>(List.of(3, 1, 2)));
        t("ArrayDeque", new ArrayDeque<>(List.of(1, 2)));
        t("Vector", new Vector<>(List.of(1)));
        t("Hashtable", new Hashtable<>(Map.of("a", 1)));
        t("Date", new Date(86400000L));
        t("BigInteger", new BigInteger("123456789012345678901234567890"));
        t("BigDecimal", new BigDecimal("12.345"));
        t("UUID", new UUID(1, 2));
        t("Optional-less", Arrays.asList(1, 2));
        t("EnumMap", new EnumMap<>(Map.of(Thread.State.NEW, 1)));
        t("List.of", List.of(1, 2, 3));
        t("Map.of", Map.of("a", 1));
        t("unmod", Collections.unmodifiableList(new ArrayList<>(List.of(1))));
        t("emptyList", Collections.emptyList());
        t("Stack", new Stack<>());
        t("Random", new Random(5));
        t("StringBuilder", new StringBuilder("sb"));
        t("BitSet", BitSet.valueOf(new long[]{5}));
        t("Locale", Locale.US);
        t("Properties", new Properties());
        t("PQ", new PriorityQueue<>(List.of(2, 1)));
        t("AtomicInteger", new java.util.concurrent.atomic.AtomicInteger(3));
        t("LocalDate", java.time.LocalDate.of(2024, 2, 29));
        t("Duration", java.time.Duration.ofSeconds(90));
        t("Boolean[]", new Boolean[]{true});
        t("Integer[]", new Integer[]{1, 2});
    }
}
