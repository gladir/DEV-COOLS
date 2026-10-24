package java.util;
import java.util.function.*;
public interface Comparator<T> {
    int compare(T o1, T o2);
    boolean equals(Object obj);
    default Comparator<T> reversed() { return Collections.reverseOrder(this); }
    default Comparator<T> thenComparing(Comparator<? super T> other) {
        return (c1, c2) -> { int res = compare(c1, c2); return (res != 0) ? res : other.compare(c1, c2); };
    }
    default <U> Comparator<T> thenComparing(Function<? super T, ? extends U> keyExtractor, Comparator<? super U> keyComparator) {
        return thenComparing(comparing(keyExtractor, keyComparator));
    }
    default <U extends Comparable<? super U>> Comparator<T> thenComparing(Function<? super T, ? extends U> keyExtractor) {
        return thenComparing(comparing(keyExtractor));
    }
    default Comparator<T> thenComparingInt(ToIntFunction<? super T> keyExtractor) { return thenComparing(comparingInt(keyExtractor)); }
    default Comparator<T> thenComparingLong(ToLongFunction<? super T> keyExtractor) { return thenComparing(comparingLong(keyExtractor)); }
    default Comparator<T> thenComparingDouble(ToDoubleFunction<? super T> keyExtractor) { return thenComparing(comparingDouble(keyExtractor)); }
    public static <T extends Comparable<? super T>> Comparator<T> reverseOrder() { return Collections.reverseOrder(); }
    public static <T extends Comparable<? super T>> Comparator<T> naturalOrder() { return (Comparator<T>) Collections.NaturalOrder.INSTANCE; }
    public static <T> Comparator<T> nullsFirst(Comparator<? super T> comparator) {
        return (a, b) -> a == null ? (b == null ? 0 : -1) : (b == null ? 1 : (comparator == null ? 0 : comparator.compare(a, b)));
    }
    public static <T> Comparator<T> nullsLast(Comparator<? super T> comparator) {
        return (a, b) -> a == null ? (b == null ? 0 : 1) : (b == null ? -1 : (comparator == null ? 0 : comparator.compare(a, b)));
    }
    public static <T, U> Comparator<T> comparing(Function<? super T, ? extends U> keyExtractor, Comparator<? super U> keyComparator) {
        return (c1, c2) -> keyComparator.compare(keyExtractor.apply(c1), keyExtractor.apply(c2));
    }
    public static <T, U extends Comparable<? super U>> Comparator<T> comparing(Function<? super T, ? extends U> keyExtractor) {
        return (c1, c2) -> keyExtractor.apply(c1).compareTo(keyExtractor.apply(c2));
    }
    public static <T> Comparator<T> comparingInt(ToIntFunction<? super T> keyExtractor) {
        return (c1, c2) -> Integer.compare(keyExtractor.applyAsInt(c1), keyExtractor.applyAsInt(c2));
    }
    public static <T> Comparator<T> comparingLong(ToLongFunction<? super T> keyExtractor) {
        return (c1, c2) -> Long.compare(keyExtractor.applyAsLong(c1), keyExtractor.applyAsLong(c2));
    }
    public static <T> Comparator<T> comparingDouble(ToDoubleFunction<? super T> keyExtractor) {
        return (c1, c2) -> Double.compare(keyExtractor.applyAsDouble(c1), keyExtractor.applyAsDouble(c2));
    }
}
