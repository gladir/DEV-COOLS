package java.util.function;
public interface DoubleUnaryOperator {
    double applyAsDouble(double operand);
    default DoubleUnaryOperator andThen(DoubleUnaryOperator after) { return (double t) -> after.applyAsDouble(applyAsDouble(t)); }
    default DoubleUnaryOperator compose(DoubleUnaryOperator before) { return (double v) -> applyAsDouble(before.applyAsDouble(v)); }
    static DoubleUnaryOperator identity() { return t -> t; }
}
