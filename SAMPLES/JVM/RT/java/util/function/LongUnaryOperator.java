package java.util.function;
public interface LongUnaryOperator {
    long applyAsLong(long operand);
    default LongUnaryOperator andThen(LongUnaryOperator after) { return (long t) -> after.applyAsLong(applyAsLong(t)); }
    default LongUnaryOperator compose(LongUnaryOperator before) { return (long v) -> applyAsLong(before.applyAsLong(v)); }
    static LongUnaryOperator identity() { return t -> t; }
}
