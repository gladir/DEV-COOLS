package java.util.function;
public interface BiPredicate<T, U> {
    boolean test(T t, U u);
    default BiPredicate<T, U> and(BiPredicate<? super T, ? super U> o) { return (T t, U u) -> test(t, u) && o.test(t, u); }
    default BiPredicate<T, U> negate() { return (T t, U u) -> !test(t, u); }
    default BiPredicate<T, U> or(BiPredicate<? super T, ? super U> o) { return (T t, U u) -> test(t, u) || o.test(t, u); }
}
