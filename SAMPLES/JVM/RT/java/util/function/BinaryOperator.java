package java.util.function;
public interface BinaryOperator<T> extends BiFunction<T, T, T> {
    static <T> BinaryOperator<T> minBy(java.util.Comparator<? super T> c) { return (a, b) -> c.compare(a, b) <= 0 ? a : b; }
    static <T> BinaryOperator<T> maxBy(java.util.Comparator<? super T> c) { return (a, b) -> c.compare(a, b) >= 0 ? a : b; }
}
