package java.util.function;
public interface IntUnaryOperator {
    int applyAsInt(int operand);
    default IntUnaryOperator andThen(IntUnaryOperator after) { return (int t) -> after.applyAsInt(applyAsInt(t)); }
    default IntUnaryOperator compose(IntUnaryOperator before) { return (int v) -> applyAsInt(before.applyAsInt(v)); }
    static IntUnaryOperator identity() { return t -> t; }
}
