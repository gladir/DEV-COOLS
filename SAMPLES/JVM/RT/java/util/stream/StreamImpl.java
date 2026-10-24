package java.util.stream;
import java.util.*;
import java.util.function.*;
public class StreamImpl<T> implements Stream<T> {
    private Iterator<T> it;
    private boolean used;
    private Runnable closeHandler;
    public StreamImpl(Iterator<T> it) { this.it = it; }
    static class BuilderImpl<T> implements Stream.Builder<T> {
        private final ArrayList<T> l = new ArrayList<>();
        public void accept(T t) { l.add(t); }
        public Stream<T> build() { return new StreamImpl<T>(l.iterator()); }
    }
    private Iterator<T> take() {
        if (used) throw new IllegalStateException("stream has already been operated upon or closed");
        used = true;
        return it;
    }
    public Iterator<T> iterator() { return take(); }
    public boolean isParallel() { return false; }
    public Stream<T> sequential() { return this; }
    public Stream<T> parallel() { return this; }
    public Stream<T> unordered() { return this; }
    public Stream<T> onClose(Runnable r) { closeHandler = r; return this; }
    public void close() { if (closeHandler != null) closeHandler.run(); }
    public Stream<T> filter(Predicate<? super T> p) {
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            T nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { T t = src.next(); if (p.test(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public T next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public <R> Stream<R> map(Function<? super T, ? extends R> f) {
        final Iterator<T> src = take();
        return new StreamImpl<R>(new Iterator<R>() {
            public boolean hasNext() { return src.hasNext(); }
            public R next() { return f.apply(src.next()); }
        });
    }
    public IntStream mapToInt(ToIntFunction<? super T> f) {
        final Iterator<T> src = take();
        return new IntStreamImpl(new IntStreamImpl.IntIter() {
            public boolean hasNext() { return src.hasNext(); }
            public int next() { return f.applyAsInt(src.next()); }
        });
    }
    public LongStream mapToLong(ToLongFunction<? super T> f) {
        final Iterator<T> src = take();
        return new LongStreamImpl(new LongStreamImpl.LongIter() {
            public boolean hasNext() { return src.hasNext(); }
            public long next() { return f.applyAsLong(src.next()); }
        });
    }
    public DoubleStream mapToDouble(ToDoubleFunction<? super T> f) {
        final Iterator<T> src = take();
        return new DoubleStreamImpl(new DoubleStreamImpl.DoubleIter() {
            public boolean hasNext() { return src.hasNext(); }
            public double next() { return f.applyAsDouble(src.next()); }
        });
    }
    public <R> Stream<R> flatMap(Function<? super T, ? extends Stream<? extends R>> f) {
        final Iterator<T> src = take();
        return new StreamImpl<R>(new Iterator<R>() {
            Iterator<? extends R> cur;
            public boolean hasNext() {
                while ((cur == null || !cur.hasNext()) && src.hasNext()) {
                    Stream<? extends R> s = f.apply(src.next());
                    cur = s == null ? null : s.iterator();
                }
                return cur != null && cur.hasNext();
            }
            public R next() { if (!hasNext()) throw new NoSuchElementException(); return cur.next(); }
        });
    }
    public IntStream flatMapToInt(Function<? super T, ? extends IntStream> f) {
        ArrayList<Integer> l = new ArrayList<>();
        Iterator<T> src = take();
        while (src.hasNext()) { IntStream s = f.apply(src.next()); if (s != null) s.forEach(x -> l.add(x)); }
        int[] a = new int[l.size()];
        for (int i = 0; i < a.length; i++) a[i] = l.get(i);
        return IntStream.of(a);
    }
    public <R> Stream<R> mapMulti(BiConsumer<? super T, ? super Consumer<R>> mapper) {
        ArrayList<R> out = new ArrayList<>();
        Iterator<T> src = take();
        Consumer<R> sink = r -> out.add(r);
        while (src.hasNext()) mapper.accept(src.next(), sink);
        return new StreamImpl<R>(out.iterator());
    }
    public Stream<T> distinct() {
        final Iterator<T> src = take();
        final HashSet<T> seen = new HashSet<>();
        return new StreamImpl<T>(new Iterator<T>() {
            T nxt; boolean ready;
            public boolean hasNext() {
                while (!ready && src.hasNext()) { T t = src.next(); if (seen.add(t)) { nxt = t; ready = true; } }
                return ready;
            }
            public T next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public Stream<T> sorted() { return sorted(null); }
    public Stream<T> sorted(Comparator<? super T> c) {
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            Iterator<T> sortedIt;
            private void init() {
                if (sortedIt == null) {
                    ArrayList<T> l = new ArrayList<>();
                    while (src.hasNext()) l.add(src.next());
                    l.sort(c);
                    sortedIt = l.iterator();
                }
            }
            public boolean hasNext() { init(); return sortedIt.hasNext(); }
            public T next() { init(); return sortedIt.next(); }
        });
    }
    public Stream<T> peek(Consumer<? super T> action) {
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            public boolean hasNext() { return src.hasNext(); }
            public T next() { T t = src.next(); action.accept(t); return t; }
        });
    }
    public Stream<T> limit(long n) {
        if (n < 0) throw new IllegalArgumentException(Long.toString(n));
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            long left = n;
            public boolean hasNext() { return left > 0 && src.hasNext(); }
            public T next() { if (left <= 0) throw new NoSuchElementException(); left--; return src.next(); }
        });
    }
    public Stream<T> skip(long n) {
        if (n < 0) throw new IllegalArgumentException(Long.toString(n));
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            long toSkip = n;
            private void sk() { while (toSkip > 0 && src.hasNext()) { src.next(); toSkip--; } toSkip = 0; }
            public boolean hasNext() { sk(); return src.hasNext(); }
            public T next() { sk(); return src.next(); }
        });
    }
    public Stream<T> takeWhile(Predicate<? super T> p) {
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            T nxt; boolean ready, done;
            public boolean hasNext() {
                if (!ready && !done && src.hasNext()) { T t = src.next(); if (p.test(t)) { nxt = t; ready = true; } else done = true; }
                return ready;
            }
            public T next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public Stream<T> dropWhile(Predicate<? super T> p) {
        final Iterator<T> src = take();
        return new StreamImpl<T>(new Iterator<T>() {
            T nxt; boolean ready, dropping = true;
            public boolean hasNext() {
                if (ready) return true;
                while (src.hasNext()) {
                    T t = src.next();
                    if (dropping && p.test(t)) continue;
                    dropping = false; nxt = t; ready = true; return true;
                }
                return false;
            }
            public T next() { if (!hasNext()) throw new NoSuchElementException(); ready = false; return nxt; }
        });
    }
    public void forEach(Consumer<? super T> action) { Iterator<T> s = take(); while (s.hasNext()) action.accept(s.next()); }
    public void forEachOrdered(Consumer<? super T> action) { forEach(action); }
    public Object[] toArray() { return toList0().toArray(); }
    public <A> A[] toArray(IntFunction<A[]> generator) {
        ArrayList<T> l = toList0();
        A[] a = generator.apply(l.size());
        for (int i = 0; i < a.length; i++) a[i] = (A) l.get(i);
        return a;
    }
    private ArrayList<T> toList0() { ArrayList<T> l = new ArrayList<>(); Iterator<T> s = take(); while (s.hasNext()) l.add(s.next()); return l; }
    public T reduce(T identity, BinaryOperator<T> acc) { T r = identity; Iterator<T> s = take(); while (s.hasNext()) r = acc.apply(r, s.next()); return r; }
    public Optional<T> reduce(BinaryOperator<T> acc) {
        Iterator<T> s = take();
        if (!s.hasNext()) return Optional.empty();
        T r = s.next();
        while (s.hasNext()) r = acc.apply(r, s.next());
        return Optional.of(r);
    }
    public <U> U reduce(U identity, BiFunction<U, ? super T, U> acc, BinaryOperator<U> combiner) { U r = identity; Iterator<T> s = take(); while (s.hasNext()) r = acc.apply(r, s.next()); return r; }
    public <R> R collect(Supplier<R> supplier, BiConsumer<R, ? super T> acc, BiConsumer<R, R> combiner) {
        R r = supplier.get(); Iterator<T> s = take(); while (s.hasNext()) acc.accept(r, s.next()); return r;
    }
    public <R, A> R collect(Collector<? super T, A, R> collector) {
        A a = collector.supplier().get();
        BiConsumer<A, ? super T> acc = collector.accumulator();
        Iterator<T> s = take();
        while (s.hasNext()) acc.accept(a, s.next());
        return collector.finisher().apply(a);
    }
    public List<T> toList() { return Collections.unmodifiableList(toList0()); }
    public Optional<T> min(Comparator<? super T> c) { return reduce((a, b) -> c.compare(a, b) <= 0 ? a : b); }
    public Optional<T> max(Comparator<? super T> c) { return reduce((a, b) -> c.compare(a, b) >= 0 ? a : b); }
    public long count() { long n = 0; Iterator<T> s = take(); while (s.hasNext()) { s.next(); n++; } return n; }
    public boolean anyMatch(Predicate<? super T> p) { Iterator<T> s = take(); while (s.hasNext()) if (p.test(s.next())) return true; return false; }
    public boolean allMatch(Predicate<? super T> p) { Iterator<T> s = take(); while (s.hasNext()) if (!p.test(s.next())) return false; return true; }
    public boolean noneMatch(Predicate<? super T> p) { return !anyMatch(p); }
    public Optional<T> findFirst() { Iterator<T> s = take(); return s.hasNext() ? Optional.of(s.next()) : Optional.empty(); }
    public Optional<T> findAny() { return findFirst(); }
}
