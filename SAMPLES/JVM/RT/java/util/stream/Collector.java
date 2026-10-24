package java.util.stream;
import java.util.*;
import java.util.function.*;
public interface Collector<T, A, R> {
    Supplier<A> supplier();
    BiConsumer<A, T> accumulator();
    BinaryOperator<A> combiner();
    Function<A, R> finisher();
    Set<Characteristics> characteristics();
    public static <T, R> Collector<T, R, R> of(Supplier<R> supplier, BiConsumer<R, T> accumulator, BinaryOperator<R> combiner, Characteristics... characteristics) {
        return new Collectors.CollectorImpl<T, R, R>(supplier, accumulator, combiner, x -> x);
    }
    public static <T, A, R> Collector<T, A, R> of(Supplier<A> supplier, BiConsumer<A, T> accumulator, BinaryOperator<A> combiner, Function<A, R> finisher, Characteristics... characteristics) {
        return new Collectors.CollectorImpl<T, A, R>(supplier, accumulator, combiner, finisher);
    }
    enum Characteristics { CONCURRENT, UNORDERED, IDENTITY_FINISH }
}
