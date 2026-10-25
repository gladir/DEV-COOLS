package java.util.function;
public interface IntConsumer {
    void accept(int value);
    default IntConsumer andThen(IntConsumer after) { return (int t) -> { accept(t); after.accept(t); }; }
}
