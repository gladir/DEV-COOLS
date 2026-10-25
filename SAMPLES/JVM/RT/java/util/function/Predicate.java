package java.util.function;
public interface Predicate<T> {
    boolean test(T t);
    default Predicate<T> and(Predicate<? super T> other) { return (t) -> test(t) && other.test(t); }
    default Predicate<T> negate() { return (t) -> !test(t); }
    default Predicate<T> or(Predicate<? super T> other) { return (t) -> test(t) || other.test(t); }
    static <T> Predicate<T> isEqual(Object target) { return (null == target) ? (t -> t == null) : (t -> target.equals(t)); }
    static <T> Predicate<T> not(Predicate<? super T> target) { return (Predicate<T>) target.negate(); }
}
