package java.util.function;
public interface DoubleConsumer {
    void accept(double value);
    default DoubleConsumer andThen(DoubleConsumer after) { return (double t) -> { accept(t); after.accept(t); }; }
}
