package java.util.stream;
import java.util.*;
import java.util.function.*;
public class LongStreamImpl implements LongStream {
    public interface LongIter { boolean hasNext(); long next(); }
    private LongIter it;
    private boolean used;
    private Runnable closeHandler;
    public LongStreamImpl(LongIter it) { this.it = it; }
    static LongIter iterOf(final long[] a) {
        return new LongIter() { int i = 0; public boolean hasNext() { return i < a.length; } public long next() { return a[i++]; } };
    }
    private LongIter take() {
        if (used) throw new IllegalStateException("stream has already been operated upon or closed");
        used = true;
        return it;
    }
    public PrimitiveIterator.OfLong iterator() {
        final LongIter s = take();
        return new PrimitiveIterator.OfLong() {
            public boolean hasNext() { return s.hasNext(); }
            public long nextLong() { return s.next(); }
            public Long next() { return s.next(); }
        };
    }
    public boolean isParallel() { return false; }
    public LongStream sequential() { return this; }
    public LongStream parallel() { return this; }
    public LongStream unordered() { return this; }
    public LongStream onClose(Runnable r) { closeHandler = r; return this; }
    public void close() { if (closeHandler != null) closeHandler.run(); }
    public LongStream filter(LongPredicate p) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            long nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { long t = src.next(); if (p.test(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public long next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public LongStream map(LongUnaryOperator f) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            public boolean hasNext() { return src.hasNext(); }
            public long next() { return f.applyAsLong(src.next()); }
        });
    }
    public <U> Stream<U> mapToObj(LongFunction<? extends U> f) {
        final LongIter src = take();
        return new StreamImpl<U>(new Iterator<U>() {
            public boolean hasNext() { return src.hasNext(); }
            public U next() { return f.apply(src.next()); }
        });
    }
    public IntStream mapToInt(LongToIntFunction f) {
        final LongIter src = take();
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            public boolean hasNext() { return src.hasNext(); }
            public int next() { return f.applyAsInt(src.next()); }
        });
    }
    public DoubleStream asDoubleStream() {
        final LongIter src = take();
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { return src.next(); }
        });
    }
    public DoubleStream mapToDouble(LongToDoubleFunction f) {
        final LongIter src = take();
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { return f.applyAsDouble(src.next()); }
        });
    }

    public LongStream flatMap(LongFunction<? extends LongStream> f) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            PrimitiveIterator.OfLong cur;
            public boolean hasNext() {
                while ((cur == null || !cur.hasNext()) && src.hasNext()) { LongStream s = f.apply(src.next()); cur = s == null ? null : s.iterator(); }
                return cur != null && cur.hasNext();
            }
            public long next() { if (!hasNext()) throw new NoSuchElementException(); return cur.nextLong(); }
        });
    }
    public LongStream distinct() {
        final LongIter src = take();
        final HashSet<Long> seen = new HashSet<>();
        return new LongStreamImpl(new LongIter() {
            long nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { long t = src.next(); if (seen.add(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public long next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public LongStream sorted() {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            long[] arr; int i;
            private void init() {
                if (arr == null) {
                    long[] a = new long[16]; int n = 0;
                    while (src.hasNext()) { if (n == a.length) a = Arrays.copyOf(a, n * 2); a[n++] = src.next(); }
                    arr = Arrays.copyOf(a, n);
                    Arrays.sort(arr);
                }
            }
            public boolean hasNext() { init(); return i < arr.length; }
            public long next() { init(); return arr[i++]; }
        });
    }
    public LongStream peek(LongConsumer action) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            public boolean hasNext() { return src.hasNext(); }
            public long next() { long t = src.next(); action.accept(t); return t; }
        });
    }
    public LongStream limit(long n) {
        if (n < 0) throw new IllegalArgumentException(Long.toString(n));
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            long left = n;
            public boolean hasNext() { return left > 0 && src.hasNext(); }
            public long next() { if (left <= 0) throw new NoSuchElementException(); left--; return src.next(); }
        });
    }
    public LongStream skip(long n) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            long toSkip = n;
            private void sk() { while (toSkip > 0 && src.hasNext()) { src.next(); toSkip--; } toSkip = 0; }
            public boolean hasNext() { sk(); return src.hasNext(); }
            public long next() { sk(); return src.next(); }
        });
    }
    public LongStream takeWhile(LongPredicate p) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            long nxt; boolean ready, done;
            public boolean hasNext() {
                if (!ready && !done && src.hasNext()) { long t = src.next(); if (p.test(t)) { nxt = t; ready = true; } else done = true; }
                return ready;
            }
            public long next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public LongStream dropWhile(LongPredicate p) {
        final LongIter src = take();
        return new LongStreamImpl(new LongIter() {
            long nxt; boolean ready, dropping = true;
            public boolean hasNext() {
                if (ready) return true;
                while (src.hasNext()) {
                    long t = src.next();
                    if (dropping && p.test(t)) continue;
                    dropping = false; nxt = t; ready = true; return true;
                }
                return false;
            }
            public long next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public void forEach(LongConsumer action) { LongIter s = take(); while (s.hasNext()) action.accept(s.next()); }
    public void forEachOrdered(LongConsumer action) { forEach(action); }
    public long[] toArray() {
        long[] a = new long[16]; int n = 0;
        LongIter s = take();
        while (s.hasNext()) { if (n == a.length) a = Arrays.copyOf(a, n * 2); a[n++] = s.next(); }
        return Arrays.copyOf(a, n);
    }
    public long reduce(long identity, LongBinaryOperator op) { long r = identity; LongIter s = take(); while (s.hasNext()) r = op.applyAsLong(r, s.next()); return r; }
    public OptionalLong reduce(LongBinaryOperator op) {
        LongIter s = take();
        if (!s.hasNext()) return OptionalLong.empty();
        long r = s.next();
        while (s.hasNext()) r = op.applyAsLong(r, s.next());
        return OptionalLong.of(r);
    }
    public long sum() { long r = 0; LongIter s = take(); while (s.hasNext()) r += s.next(); return r; }
    public OptionalLong min() { return reduce((a, b) -> Math.min(a, b)); }
    public OptionalLong max() { return reduce((a, b) -> Math.max(a, b)); }
    public long count() { long n = 0; LongIter s = take(); while (s.hasNext()) { s.next(); n++; } return n; }
    public OptionalDouble average() {
        double sum = 0; long n = 0; LongIter s = take();
        while (s.hasNext()) { sum += s.next(); n++; }
        return n == 0 ? OptionalDouble.empty() : OptionalDouble.of(sum / n);
    }
    public LongSummaryStatistics summaryStatistics() {
        LongSummaryStatistics st = new LongSummaryStatistics();
        LongIter s = take();
        while (s.hasNext()) st.accept(s.next());
        return st;
    }
    public boolean anyMatch(LongPredicate p) { LongIter s = take(); while (s.hasNext()) if (p.test(s.next())) return true; return false; }
    public boolean allMatch(LongPredicate p) { LongIter s = take(); while (s.hasNext()) if (!p.test(s.next())) return false; return true; }
    public boolean noneMatch(LongPredicate p) { return !anyMatch(p); }
    public OptionalLong findFirst() { LongIter s = take(); return s.hasNext() ? OptionalLong.of(s.next()) : OptionalLong.empty(); }
    public OptionalLong findAny() { return findFirst(); }
    public Stream<Long> boxed() { return mapToObj(x -> x); }
    public <R> R collect(Supplier<R> supplier, ObjLongConsumer<R> acc, BiConsumer<R, R> combiner) {
        R r = supplier.get(); LongIter s = take(); while (s.hasNext()) acc.accept(r, s.next()); return r;
    }
}
