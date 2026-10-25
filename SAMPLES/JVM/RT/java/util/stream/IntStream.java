package java.util.stream;
import java.util.*;
import java.util.function.*;
public interface IntStream extends BaseStream<Integer, IntStream> {
    IntStream filter(IntPredicate predicate);
    IntStream map(IntUnaryOperator mapper);
    <U> Stream<U> mapToObj(IntFunction<? extends U> mapper);
    LongStream asLongStream();
    LongStream mapToLong(IntToLongFunction mapper);
    DoubleStream asDoubleStream();
    DoubleStream mapToDouble(IntToDoubleFunction mapper);

    IntStream flatMap(IntFunction<? extends IntStream> mapper);
    IntStream distinct();
    IntStream sorted();
    IntStream peek(IntConsumer action);
    IntStream limit(long maxSize);
    IntStream skip(long n);
    IntStream takeWhile(IntPredicate predicate);
    IntStream dropWhile(IntPredicate predicate);
    void forEach(IntConsumer action);
    void forEachOrdered(IntConsumer action);
    int[] toArray();
    int reduce(int identity, IntBinaryOperator op);
    OptionalInt reduce(IntBinaryOperator op);
    int sum();
    OptionalInt min();
    OptionalInt max();
    long count();
    OptionalDouble average();
    IntSummaryStatistics summaryStatistics();
    boolean anyMatch(IntPredicate predicate);
    boolean allMatch(IntPredicate predicate);
    boolean noneMatch(IntPredicate predicate);
    OptionalInt findFirst();
    OptionalInt findAny();
    Stream<Integer> boxed();
    <R> R collect(Supplier<R> supplier, ObjIntConsumer<R> accumulator, BiConsumer<R, R> combiner);
    PrimitiveIterator.OfInt iterator();
    public static IntStream empty() { return IntStream.of(new int[0]); }
    public static IntStream of(int t) { return IntStream.of(new int[] { t }); }
    public static IntStream of(int... values) { return new IntStreamImpl(IntStreamImpl.iterOf(values)); }
    public static IntStream iterate(final int seed, final IntUnaryOperator f) {
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            int cur = seed; boolean first = true;
            public boolean hasNext() { return true; }
            public int next() { if (first) { first = false; return cur; } cur = f.applyAsInt(cur); return cur; }
        });
    }
    public static IntStream iterate(final int seed, final IntPredicate hasNext, final IntUnaryOperator next) {
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            int cur = seed; boolean first = true, ready = false, done = false;
            private void adv() {
                if (ready || done) return;
                if (first) first = false; else cur = next.applyAsInt(cur);
                if (hasNext.test(cur)) ready = true; else done = true;
            }
            public boolean hasNext() { adv(); return ready; }
            public int next() { adv(); if (!ready) throw new NoSuchElementException(); ready = false; return cur; }
        });
    }
    public static IntStream generate(final IntSupplier s) {
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            public boolean hasNext() { return true; }
            public int next() { return s.getAsInt(); }
        });
    }
    public static IntStream concat(IntStream a, IntStream b) {
        final PrimitiveIterator.OfInt ia = a.iterator(), ib = b.iterator();
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            public boolean hasNext() { return ia.hasNext() || ib.hasNext(); }
            public int next() { return ia.hasNext() ? ia.nextInt() : ib.nextInt(); }
        });
    }
    public static IntStream range(int a, int b) {
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            int i = a;
            public boolean hasNext() { return i < b; }
            public int next() { return i++; }
        });
    }
    public static IntStream rangeClosed(int a, int b) {
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            long i = a;
            public boolean hasNext() { return i <= b; }
            public int next() { return (int) i++; }
        });
    }

}
