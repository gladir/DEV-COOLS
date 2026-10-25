package java.util.function;
public interface Consumer<T> {
    void accept(T t);
    default Consumer<T> andThen(Consumer<? super T> after) { return (T t) -> { accept(t); after.accept(t); }; }
}
