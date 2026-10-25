package java.util.stream;
import java.util.*;
import java.util.function.*;
public class DoubleStreamImpl implements DoubleStream {
    public interface DoubleIter { boolean hasNext(); double next(); }
    private DoubleIter it;
    private boolean used;
    private Runnable closeHandler;
    public DoubleStreamImpl(DoubleIter it) { this.it = it; }
    static DoubleIter iterOf(final double[] a) {
        return new DoubleIter() { int i = 0; public boolean hasNext() { return i < a.length; } public double next() { return a[i++]; } };
    }
    private DoubleIter take() {
        if (used) throw new IllegalStateException("stream has already been operated upon or closed");
        used = true;
        return it;
    }
    public PrimitiveIterator.OfDouble iterator() {
        final DoubleIter s = take();
        return new PrimitiveIterator.OfDouble() {
            public boolean hasNext() { return s.hasNext(); }
            public double nextDouble() { return s.next(); }
            public Double next() { return s.next(); }
        };
    }
    public boolean isParallel() { return false; }
    public DoubleStream sequential() { return this; }
    public DoubleStream parallel() { return this; }
    public DoubleStream unordered() { return this; }
    public DoubleStream onClose(Runnable r) { closeHandler = r; return this; }
    public void close() { if (closeHandler != null) closeHandler.run(); }
    public DoubleStream filter(DoublePredicate p) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            double nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { double t = src.next(); if (p.test(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public double next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public DoubleStream map(DoubleUnaryOperator f) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { return f.applyAsDouble(src.next()); }
        });
    }
    public <U> Stream<U> mapToObj(DoubleFunction<? extends U> f) {
        final DoubleIter src = take();
        return new StreamImpl<U>(new Iterator<U>() {
            public boolean hasNext() { return src.hasNext(); }
            public U next() { return f.apply(src.next()); }
        });
    }
    public IntStream mapToInt(DoubleToIntFunction f) {
        final DoubleIter src = take();
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            public boolean hasNext() { return src.hasNext(); }
            public int next() { return f.applyAsInt(src.next()); }
        });
    }
    public LongStream mapToLong(DoubleToLongFunction f) {
        final DoubleIter src = take();
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            public boolean hasNext() { return src.hasNext(); }
            public long next() { return f.applyAsLong(src.next()); }
        });
    }

    public DoubleStream flatMap(DoubleFunction<? extends DoubleStream> f) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            PrimitiveIterator.OfDouble cur;
            public boolean hasNext() {
                while ((cur == null || !cur.hasNext()) && src.hasNext()) { DoubleStream s = f.apply(src.next()); cur = s == null ? null : s.iterator(); }
                return cur != null && cur.hasNext();
            }
            public double next() { if (!hasNext()) throw new NoSuchElementException(); return cur.nextDouble(); }
        });
    }
    public DoubleStream distinct() {
        final DoubleIter src = take();
        final HashSet<Double> seen = new HashSet<>();
        return new DoubleStreamImpl(new DoubleIter() {
            double nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { double t = src.next(); if (seen.add(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public double next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public DoubleStream sorted() {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            double[] arr; int i;
            private void init() {
                if (arr == null) {
                    double[] a = new double[16]; int n = 0;
                    while (src.hasNext()) { if (n == a.length) a = Arrays.copyOf(a, n * 2); a[n++] = src.next(); }
                    arr = Arrays.copyOf(a, n);
                    Arrays.sort(arr);
                }
            }
            public boolean hasNext() { init(); return i < arr.length; }
            public double next() { init(); return arr[i++]; }
        });
    }
    public DoubleStream peek(DoubleConsumer action) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { double t = src.next(); action.accept(t); return t; }
        });
    }
    public DoubleStream limit(long n) {
        if (n < 0) throw new IllegalArgumentException(Long.toString(n));
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            long left = n;
            public boolean hasNext() { return left > 0 && src.hasNext(); }
            public double next() { if (left <= 0) throw new NoSuchElementException(); left--; return src.next(); }
        });
    }
    public DoubleStream skip(long n) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            long toSkip = n;
            private void sk() { while (toSkip > 0 && src.hasNext()) { src.next(); toSkip--; } toSkip = 0; }
            public boolean hasNext() { sk(); return src.hasNext(); }
            public double next() { sk(); return src.next(); }
        });
    }
    public DoubleStream takeWhile(DoublePredicate p) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            double nxt; boolean ready, done;
            public boolean hasNext() {
                if (!ready && !done && src.hasNext()) { double t = src.next(); if (p.test(t)) { nxt = t; ready = true; } else done = true; }
                return ready;
            }
            public double next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public DoubleStream dropWhile(DoublePredicate p) {
        final DoubleIter src = take();
        return new DoubleStreamImpl(new DoubleIter() {
            double nxt; boolean ready, dropping = true;
            public boolean hasNext() {
                if (ready) return true;
                while (src.hasNext()) {
                    double t = src.next();
                    if (dropping && p.test(t)) continue;
                    dropping = false; nxt = t; ready = true; return true;
                }
                return false;
            }
            public double next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public void forEach(DoubleConsumer action) { DoubleIter s = take(); while (s.hasNext()) action.accept(s.next()); }
    public void forEachOrdered(DoubleConsumer action) { forEach(action); }
    public double[] toArray() {
        double[] a = new double[16]; int n = 0;
        DoubleIter s = take();
        while (s.hasNext()) { if (n == a.length) a = Arrays.copyOf(a, n * 2); a[n++] = s.next(); }
        return Arrays.copyOf(a, n);
    }
    public double reduce(double identity, DoubleBinaryOperator op) { double r = identity; DoubleIter s = take(); while (s.hasNext()) r = op.applyAsDouble(r, s.next()); return r; }
    public OptionalDouble reduce(DoubleBinaryOperator op) {
        DoubleIter s = take();
        if (!s.hasNext()) return OptionalDouble.empty();
        double r = s.next();
        while (s.hasNext()) r = op.applyAsDouble(r, s.next());
        return OptionalDouble.of(r);
    }
    public double sum() { double r = 0; DoubleIter s = take(); while (s.hasNext()) r += s.next(); return r; }
    public OptionalDouble min() { return reduce((a, b) -> Math.min(a, b)); }
    public OptionalDouble max() { return reduce((a, b) -> Math.max(a, b)); }
    public long count() { long n = 0; DoubleIter s = take(); while (s.hasNext()) { s.next(); n++; } return n; }
    public OptionalDouble average() {
        double sum = 0; long n = 0; DoubleIter s = take();
        while (s.hasNext()) { sum += s.next(); n++; }
        return n == 0 ? OptionalDouble.empty() : OptionalDouble.of(sum / n);
    }
    public DoubleSummaryStatistics summaryStatistics() {
        DoubleSummaryStatistics st = new DoubleSummaryStatistics();
        DoubleIter s = take();
        while (s.hasNext()) st.accept(s.next());
        return st;
    }
    public boolean anyMatch(DoublePredicate p) { DoubleIter s = take(); while (s.hasNext()) if (p.test(s.next())) return true; return false; }
    public boolean allMatch(DoublePredicate p) { DoubleIter s = take(); while (s.hasNext()) if (!p.test(s.next())) return false; return true; }
    public boolean noneMatch(DoublePredicate p) { return !anyMatch(p); }
    public OptionalDouble findFirst() { DoubleIter s = take(); return s.hasNext() ? OptionalDouble.of(s.next()) : OptionalDouble.empty(); }
    public OptionalDouble findAny() { return findFirst(); }
    public Stream<Double> boxed() { return mapToObj(x -> x); }
    public <R> R collect(Supplier<R> supplier, ObjDoubleConsumer<R> acc, BiConsumer<R, R> combiner) {
        R r = supplier.get(); DoubleIter s = take(); while (s.hasNext()) acc.accept(r, s.next()); return r;
    }
}
