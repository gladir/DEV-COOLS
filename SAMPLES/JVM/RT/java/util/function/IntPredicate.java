package java.util.function;
public interface IntPredicate {
    boolean test(int value);
    default IntPredicate and(IntPredicate o) { return (v) -> test(v) && o.test(v); }
    default IntPredicate negate() { return (v) -> !test(v); }
    default IntPredicate or(IntPredicate o) { return (v) -> test(v) || o.test(v); }
}
