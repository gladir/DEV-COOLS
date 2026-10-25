package java.util.function;
public interface LongPredicate {
    boolean test(long value);
    default LongPredicate and(LongPredicate o) { return (v) -> test(v) && o.test(v); }
    default LongPredicate negate() { return (v) -> !test(v); }
    default LongPredicate or(LongPredicate o) { return (v) -> test(v) || o.test(v); }
}
