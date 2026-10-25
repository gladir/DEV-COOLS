package java.util.stream;
import java.util.*;
import java.util.function.*;
public interface LongStream extends BaseStream<Long, LongStream> {
    LongStream filter(LongPredicate predicate);
    LongStream map(LongUnaryOperator mapper);
    <U> Stream<U> mapToObj(LongFunction<? extends U> mapper);
    IntStream mapToInt(LongToIntFunction mapper);
    DoubleStream asDoubleStream();
    DoubleStream mapToDouble(LongToDoubleFunction mapper);

    LongStream flatMap(LongFunction<? extends LongStream> mapper);
    LongStream distinct();
    LongStream sorted();
    LongStream peek(LongConsumer action);
    LongStream limit(long maxSize);
    LongStream skip(long n);
    LongStream takeWhile(LongPredicate predicate);
    LongStream dropWhile(LongPredicate predicate);
    void forEach(LongConsumer action);
    void forEachOrdered(LongConsumer action);
    long[] toArray();
    long reduce(long identity, LongBinaryOperator op);
    OptionalLong reduce(LongBinaryOperator op);
    long sum();
    OptionalLong min();
    OptionalLong max();
    long count();
    OptionalDouble average();
    LongSummaryStatistics summaryStatistics();
    boolean anyMatch(LongPredicate predicate);
    boolean allMatch(LongPredicate predicate);
    boolean noneMatch(LongPredicate predicate);
    OptionalLong findFirst();
    OptionalLong findAny();
    Stream<Long> boxed();
    <R> R collect(Supplier<R> supplier, ObjLongConsumer<R> accumulator, BiConsumer<R, R> combiner);
    PrimitiveIterator.OfLong iterator();
    public static LongStream empty() { return LongStream.of(new long[0]); }
    public static LongStream of(long t) { return LongStream.of(new long[] { t }); }
    public static LongStream of(long... values) { return new LongStreamImpl(LongStreamImpl.iterOf(values)); }
    public static LongStream iterate(final long seed, final LongUnaryOperator f) {
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            long cur = seed; boolean first = true;
            public boolean hasNext() { return true; }
            public long next() { if (first) { first = false; return cur; } cur = f.applyAsLong(cur); return cur; }
        });
    }
    public static LongStream iterate(final long seed, final LongPredicate hasNext, final LongUnaryOperator next) {
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            long cur = seed; boolean first = true, ready = false, done = false;
            private void adv() {
                if (ready || done) return;
                if (first) first = false; else cur = next.applyAsLong(cur);
                if (hasNext.test(cur)) ready = true; else done = true;
            }
            public boolean hasNext() { adv(); return ready; }
            public long next() { adv(); if (!ready) throw new NoSuchElementException(); ready = false; return cur; }
        });
    }
    public static LongStream generate(final LongSupplier s) {
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            public boolean hasNext() { return true; }
            public long next() { return s.getAsLong(); }
        });
    }
    public static LongStream concat(LongStream a, LongStream b) {
        final PrimitiveIterator.OfLong ia = a.iterator(), ib = b.iterator();
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            public boolean hasNext() { return ia.hasNext() || ib.hasNext(); }
            public long next() { return ia.hasNext() ? ia.nextLong() : ib.nextLong(); }
        });
    }
    public static LongStream range(long a, long b) {
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            long i = a;
            public boolean hasNext() { return i < b; }
            public long next() { return i++; }
        });
    }
    public static LongStream rangeClosed(long a, long b) {
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            long i = a; boolean done = a > b;
            public boolean hasNext() { return !done; }
            public long next() { long r = i; if (i == b) done = true; else i++; return r; }
        });
    }

}
