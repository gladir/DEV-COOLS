package java.util.stream;
import java.util.*;
import java.util.function.*;
public interface Stream<T> extends BaseStream<T, Stream<T>> {
    Stream<T> filter(Predicate<? super T> predicate);
    <R> Stream<R> map(Function<? super T, ? extends R> mapper);
    IntStream mapToInt(ToIntFunction<? super T> mapper);
    LongStream mapToLong(ToLongFunction<? super T> mapper);
    DoubleStream mapToDouble(ToDoubleFunction<? super T> mapper);
    <R> Stream<R> flatMap(Function<? super T, ? extends Stream<? extends R>> mapper);
    IntStream flatMapToInt(Function<? super T, ? extends IntStream> mapper);
    <R> Stream<R> mapMulti(BiConsumer<? super T, ? super Consumer<R>> mapper);
    Stream<T> distinct();
    Stream<T> sorted();
    Stream<T> sorted(Comparator<? super T> comparator);
    Stream<T> peek(Consumer<? super T> action);
    Stream<T> limit(long maxSize);
    Stream<T> skip(long n);
    Stream<T> takeWhile(Predicate<? super T> predicate);
    Stream<T> dropWhile(Predicate<? super T> predicate);
    void forEach(Consumer<? super T> action);
    void forEachOrdered(Consumer<? super T> action);
    Object[] toArray();
    <A> A[] toArray(IntFunction<A[]> generator);
    T reduce(T identity, BinaryOperator<T> accumulator);
    Optional<T> reduce(BinaryOperator<T> accumulator);
    <U> U reduce(U identity, BiFunction<U, ? super T, U> accumulator, BinaryOperator<U> combiner);
    <R> R collect(Supplier<R> supplier, BiConsumer<R, ? super T> accumulator, BiConsumer<R, R> combiner);
    <R, A> R collect(Collector<? super T, A, R> collector);
    List<T> toList();
    Optional<T> min(Comparator<? super T> comparator);
    Optional<T> max(Comparator<? super T> comparator);
    long count();
    boolean anyMatch(Predicate<? super T> predicate);
    boolean allMatch(Predicate<? super T> predicate);
    boolean noneMatch(Predicate<? super T> predicate);
    Optional<T> findFirst();
    Optional<T> findAny();
    public static <T> Builder<T> builder() { return new StreamImpl.BuilderImpl<T>(); }
    public static <T> Stream<T> empty() { return new StreamImpl<T>(new ArrayList<T>().iterator()); }
    public static <T> Stream<T> of(T t) { ArrayList<T> l = new ArrayList<>(); l.add(t); return new StreamImpl<T>(l.iterator()); }
    public static <T> Stream<T> ofNullable(T t) { return t == null ? Stream.empty() : Stream.of(t); }
    public static <T> Stream<T> of(T... values) { return new StreamImpl<T>(Arrays.asList(values).iterator()); }
    public static <T> Stream<T> iterate(final T seed, final UnaryOperator<T> f) {
        return new StreamImpl<T>(new Iterator<T>() {
            T cur = seed; boolean first = true;
            public boolean hasNext() { return true; }
            public T next() { if (first) { first = false; return cur; } cur = f.apply(cur); return cur; }
        });
    }
    public static <T> Stream<T> iterate(T seed, Predicate<? super T> hasNext, UnaryOperator<T> next) {
        return new StreamImpl<T>(new Iterator<T>() {
            T cur = seed; boolean first = true, ready = false, done = false;
            private void adv() {
                if (ready || done) return;
                if (first) first = false; else cur = next.apply(cur);
                if (hasNext.test(cur)) ready = true; else done = true;
            }
            public boolean hasNext() { adv(); return ready; }
            public T next() { adv(); if (!ready) throw new NoSuchElementException(); ready = false; return cur; }
        });
    }
    public static <T> Stream<T> generate(Supplier<? extends T> s) {
        return new StreamImpl<T>(new Iterator<T>() {
            public boolean hasNext() { return true; }
            public T next() { return s.get(); }
        });
    }
    public static <T> Stream<T> concat(Stream<? extends T> a, Stream<? extends T> b) {
        final Iterator<? extends T> ia = a.iterator(), ib = b.iterator();
        return new StreamImpl<T>(new Iterator<T>() {
            public boolean hasNext() { return ia.hasNext() || ib.hasNext(); }
            public T next() { return ia.hasNext() ? ia.next() : ib.next(); }
        });
    }
    public interface Builder<T> extends Consumer<T> {
        void accept(T t);
        default Builder<T> add(T t) { accept(t); return this; }
        Stream<T> build();
    }
}
