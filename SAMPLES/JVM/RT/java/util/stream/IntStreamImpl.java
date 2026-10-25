package java.util.stream;
import java.util.*;
import java.util.function.*;
public class IntStreamImpl implements IntStream {
    public interface IntIter { boolean hasNext(); int next(); }
    private IntIter it;
    private boolean used;
    private Runnable closeHandler;
    public IntStreamImpl(IntIter it) { this.it = it; }
    static IntIter iterOf(final int[] a) {
        return new IntIter() { int i = 0; public boolean hasNext() { return i < a.length; } public int next() { return a[i++]; } };
    }
    private IntIter take() {
        if (used) throw new IllegalStateException("stream has already been operated upon or closed");
        used = true;
        return it;
    }
    public PrimitiveIterator.OfInt iterator() {
        final IntIter s = take();
        return new PrimitiveIterator.OfInt() {
            public boolean hasNext() { return s.hasNext(); }
            public int nextInt() { return s.next(); }
            public Integer next() { return s.next(); }
        };
    }
    public boolean isParallel() { return false; }
    public IntStream sequential() { return this; }
    public IntStream parallel() { return this; }
    public IntStream unordered() { return this; }
    public IntStream onClose(Runnable r) { closeHandler = r; return this; }
    public void close() { if (closeHandler != null) closeHandler.run(); }
    public IntStream filter(IntPredicate p) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            int nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { int t = src.next(); if (p.test(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public int next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public IntStream map(IntUnaryOperator f) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            public boolean hasNext() { return src.hasNext(); }
            public int next() { return f.applyAsInt(src.next()); }
        });
    }
    public <U> Stream<U> mapToObj(IntFunction<? extends U> f) {
        final IntIter src = take();
        return new StreamImpl<U>(new Iterator<U>() {
            public boolean hasNext() { return src.hasNext(); }
            public U next() { return f.apply(src.next()); }
        });
    }
    public LongStream asLongStream() {
        final IntIter src = take();
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            public boolean hasNext() { return src.hasNext(); }
            public long next() { return src.next(); }
        });
    }
    public LongStream mapToLong(IntToLongFunction f) {
        final IntIter src = take();
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            public boolean hasNext() { return src.hasNext(); }
            public long next() { return f.applyAsLong(src.next()); }
        });
    }
    public DoubleStream asDoubleStream() {
        final IntIter src = take();
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { return src.next(); }
        });
    }
    public DoubleStream mapToDouble(IntToDoubleFunction f) {
        final IntIter src = take();
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { return f.applyAsDouble(src.next()); }
        });
    }

    public IntStream flatMap(IntFunction<? extends IntStream> f) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            PrimitiveIterator.OfInt cur;
            public boolean hasNext() {
                while ((cur == null || !cur.hasNext()) && src.hasNext()) { IntStream s = f.apply(src.next()); cur = s == null ? null : s.iterator(); }
                return cur != null && cur.hasNext();
            }
            public int next() { if (!hasNext()) throw new NoSuchElementException(); return cur.nextInt(); }
        });
    }
    public IntStream distinct() {
        final IntIter src = take();
        final HashSet<Integer> seen = new HashSet<>();
        return new IntStreamImpl(new IntIter() {
            int nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { int t = src.next(); if (seen.add(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public int next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public IntStream sorted() {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            int[] arr; int i;
            private void init() {
                if (arr == null) {
                    int[] a = new int[16]; int n = 0;
                    while (src.hasNext()) { if (n == a.length) a = Arrays.copyOf(a, n * 2); a[n++] = src.next(); }
                    arr = Arrays.copyOf(a, n);
                    Arrays.sort(arr);
                }
            }
            public boolean hasNext() { init(); return i < arr.length; }
            public int next() { init(); return arr[i++]; }
        });
    }
    public IntStream peek(IntConsumer action) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            public boolean hasNext() { return src.hasNext(); }
            public int next() { int t = src.next(); action.accept(t); return t; }
        });
    }
    public IntStream limit(long n) {
        if (n < 0) throw new IllegalArgumentException(Long.toString(n));
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            long left = n;
            public boolean hasNext() { return left > 0 && src.hasNext(); }
            public int next() { if (left <= 0) throw new NoSuchElementException(); left--; return src.next(); }
        });
    }
    public IntStream skip(long n) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            long toSkip = n;
            private void sk() { while (toSkip > 0 && src.hasNext()) { src.next(); toSkip--; } toSkip = 0; }
            public boolean hasNext() { sk(); return src.hasNext(); }
            public int next() { sk(); return src.next(); }
        });
    }
    public IntStream takeWhile(IntPredicate p) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            int nxt; boolean ready, done;
            public boolean hasNext() {
                if (!ready && !done && src.hasNext()) { int t = src.next(); if (p.test(t)) { nxt = t; ready = true; } else done = true; }
                return ready;
            }
            public int next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public IntStream dropWhile(IntPredicate p) {
        final IntIter src = take();
        return new IntStreamImpl(new IntIter() {
            int nxt; boolean ready, dropping = true;
            public boolean hasNext() {
                if (ready) return true;
                while (src.hasNext()) {
                    int t = src.next();
                    if (dropping && p.test(t)) continue;
                    dropping = false; nxt = t; ready = true; return true;
                }
                return false;
            }
            public int next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public void forEach(IntConsumer action) { IntIter s = take(); while (s.hasNext()) action.accept(s.next()); }
    public void forEachOrdered(IntConsumer action) { forEach(action); }
    public int[] toArray() {
        int[] a = new int[16]; int n = 0;
        IntIter s = take();
        while (s.hasNext()) { if (n == a.length) a = Arrays.copyOf(a, n * 2); a[n++] = s.next(); }
        return Arrays.copyOf(a, n);
    }
    public int reduce(int identity, IntBinaryOperator op) { int r = identity; IntIter s = take(); while (s.hasNext()) r = op.applyAsInt(r, s.next()); return r; }
    public OptionalInt reduce(IntBinaryOperator op) {
        IntIter s = take();
        if (!s.hasNext()) return OptionalInt.empty();
        int r = s.next();
        while (s.hasNext()) r = op.applyAsInt(r, s.next());
        return OptionalInt.of(r);
    }
    public int sum() { int r = 0; IntIter s = take(); while (s.hasNext()) r += s.next(); return r; }
    public OptionalInt min() { return reduce((a, b) -> Math.min(a, b)); }
    public OptionalInt max() { return reduce((a, b) -> Math.max(a, b)); }
    public long count() { long n = 0; IntIter s = take(); while (s.hasNext()) { s.next(); n++; } return n; }
    public OptionalDouble average() {
        double sum = 0; long n = 0; IntIter s = take();
        while (s.hasNext()) { sum += s.next(); n++; }
        return n == 0 ? OptionalDouble.empty() : OptionalDouble.of(sum / n);
    }
    public IntSummaryStatistics summaryStatistics() {
        IntSummaryStatistics st = new IntSummaryStatistics();
        IntIter s = take();
        while (s.hasNext()) st.accept(s.next());
        return st;
    }
    public boolean anyMatch(IntPredicate p) { IntIter s = take(); while (s.hasNext()) if (p.test(s.next())) return true; return false; }
    public boolean allMatch(IntPredicate p) { IntIter s = take(); while (s.hasNext()) if (!p.test(s.next())) return false; return true; }
    public boolean noneMatch(IntPredicate p) { return !anyMatch(p); }
    public OptionalInt findFirst() { IntIter s = take(); return s.hasNext() ? OptionalInt.of(s.next()) : OptionalInt.empty(); }
    public OptionalInt findAny() { return findFirst(); }
    public Stream<Integer> boxed() { return mapToObj(x -> x); }
    public <R> R collect(Supplier<R> supplier, ObjIntConsumer<R> acc, BiConsumer<R, R> combiner) {
        R r = supplier.get(); IntIter s = take(); while (s.hasNext()) acc.accept(r, s.next()); return r;
    }
}
