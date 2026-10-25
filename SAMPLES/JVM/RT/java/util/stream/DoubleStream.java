package java.util.stream;
import java.util.*;
import java.util.function.*;
public interface DoubleStream extends BaseStream<Double, DoubleStream> {
    DoubleStream filter(DoublePredicate predicate);
    DoubleStream map(DoubleUnaryOperator mapper);
    <U> Stream<U> mapToObj(DoubleFunction<? extends U> mapper);
    IntStream mapToInt(DoubleToIntFunction mapper);
    LongStream mapToLong(DoubleToLongFunction mapper);

    DoubleStream flatMap(DoubleFunction<? extends DoubleStream> mapper);
    DoubleStream distinct();
    DoubleStream sorted();
    DoubleStream peek(DoubleConsumer action);
    DoubleStream limit(long maxSize);
    DoubleStream skip(long n);
    DoubleStream takeWhile(DoublePredicate predicate);
    DoubleStream dropWhile(DoublePredicate predicate);
    void forEach(DoubleConsumer action);
    void forEachOrdered(DoubleConsumer action);
    double[] toArray();
    double reduce(double identity, DoubleBinaryOperator op);
    OptionalDouble reduce(DoubleBinaryOperator op);
    double sum();
    OptionalDouble min();
    OptionalDouble max();
    long count();
    OptionalDouble average();
    DoubleSummaryStatistics summaryStatistics();
    boolean anyMatch(DoublePredicate predicate);
    boolean allMatch(DoublePredicate predicate);
    boolean noneMatch(DoublePredicate predicate);
    OptionalDouble findFirst();
    OptionalDouble findAny();
    Stream<Double> boxed();
    <R> R collect(Supplier<R> supplier, ObjDoubleConsumer<R> accumulator, BiConsumer<R, R> combiner);
    PrimitiveIterator.OfDouble iterator();
    public static DoubleStream empty() { return DoubleStream.of(new double[0]); }
    public static DoubleStream of(double t) { return DoubleStream.of(new double[] { t }); }
    public static DoubleStream of(double... values) { return new DoubleStreamImpl(DoubleStreamImpl.iterOf(values)); }
    public static DoubleStream iterate(final double seed, final DoubleUnaryOperator f) {
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            double cur = seed; boolean first = true;
            public boolean hasNext() { return true; }
            public double next() { if (first) { first = false; return cur; } cur = f.applyAsDouble(cur); return cur; }
        });
    }
    public static DoubleStream iterate(final double seed, final DoublePredicate hasNext, final DoubleUnaryOperator next) {
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            double cur = seed; boolean first = true, ready = false, done = false;
            private void adv() {
                if (ready || done) return;
                if (first) first = false; else cur = next.applyAsDouble(cur);
                if (hasNext.test(cur)) ready = true; else done = true;
            }
            public boolean hasNext() { adv(); return ready; }
            public double next() { adv(); if (!ready) throw new NoSuchElementException(); ready = false; return cur; }
        });
    }
    public static DoubleStream generate(final DoubleSupplier s) {
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return true; }
            public double next() { return s.getAsDouble(); }
        });
    }
    public static DoubleStream concat(DoubleStream a, DoubleStream b) {
        final PrimitiveIterator.OfDouble ia = a.iterator(), ib = b.iterator();
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return ia.hasNext() || ib.hasNext(); }
            public double next() { return ia.hasNext() ? ia.nextDouble() : ib.nextDouble(); }
        });
    }

}
