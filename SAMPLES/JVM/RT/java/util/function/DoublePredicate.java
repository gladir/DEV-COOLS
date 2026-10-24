package java.util.function;
public interface DoublePredicate {
    boolean test(double value);
    default DoublePredicate and(DoublePredicate o) { return (v) -> test(v) && o.test(v); }
    default DoublePredicate negate() { return (v) -> !test(v); }
    default DoublePredicate or(DoublePredicate o) { return (v) -> test(v) || o.test(v); }
}
