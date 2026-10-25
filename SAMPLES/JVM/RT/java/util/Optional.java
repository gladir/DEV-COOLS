package java.util;
import java.util.function.*;
import java.util.stream.Stream;
public final class Optional<T> {
    private static final Optional<?> EMPTY = new Optional<>(null);
    private final T value;
    public static <T> Optional<T> empty() { return (Optional<T>) EMPTY; }
    private Optional(T value) { this.value = value; }
    public static <T> Optional<T> of(T value) { return new Optional<>(Objects.requireNonNull(value)); }
    public static <T> Optional<T> ofNullable(T value) { return value == null ? (Optional<T>) EMPTY : new Optional<>(value); }
    public T get() { if (value == null) throw new NoSuchElementException("No value present"); return value; }
    public boolean isPresent() { return value != null; }
    public boolean isEmpty() { return value == null; }
    public void ifPresent(Consumer<? super T> action) { if (value != null) action.accept(value); }
    public void ifPresentOrElse(Consumer<? super T> action, Runnable emptyAction) { if (value != null) action.accept(value); else emptyAction.run(); }
    public Optional<T> filter(Predicate<? super T> predicate) { Objects.requireNonNull(predicate); if (!isPresent()) return this; else return predicate.test(value) ? this : (Optional<T>) EMPTY; }
    public <U> Optional<U> map(Function<? super T, ? extends U> mapper) { Objects.requireNonNull(mapper); if (!isPresent()) return empty(); else return Optional.ofNullable(mapper.apply(value)); }
    public <U> Optional<U> flatMap(Function<? super T, ? extends Optional<? extends U>> mapper) {
        Objects.requireNonNull(mapper);
        if (!isPresent()) return empty();
        Optional<U> r = (Optional<U>) mapper.apply(value);
        return Objects.requireNonNull(r);
    }
    public Optional<T> or(Supplier<? extends Optional<? extends T>> supplier) {
        if (isPresent()) return this;
        return (Optional<T>) Objects.requireNonNull(supplier.get());
    }
    public Stream<T> stream() { if (!isPresent()) return Stream.empty(); else return Stream.of(value); }
    public T orElse(T other) { return value != null ? value : other; }
    public T orElseGet(Supplier<? extends T> supplier) { return value != null ? value : supplier.get(); }
    public T orElseThrow() { if (value == null) throw new NoSuchElementException("No value present"); return value; }
    public <X extends Throwable> T orElseThrow(Supplier<? extends X> exceptionSupplier) throws X {
        if (value != null) return value; else throw exceptionSupplier.get();
    }
    public boolean equals(Object obj) {
        if (this == obj) return true;
        return obj instanceof Optional<?> other && Objects.equals(value, other.value);
    }
    public int hashCode() { return Objects.hashCode(value); }
    public String toString() { return value != null ? ("Optional[" + value + "]") : "Optional.empty"; }
}
