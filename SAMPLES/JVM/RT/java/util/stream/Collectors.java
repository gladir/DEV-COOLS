package java.util.stream;
import java.util.*;
import java.util.function.*;
public final class Collectors {
    private Collectors() {}
    static class CollectorImpl<T, A, R> implements Collector<T, A, R> {
        private final Supplier<A> supplier;
        private final BiConsumer<A, T> accumulator;
        private final BinaryOperator<A> combiner;
        private final Function<A, R> finisher;
        CollectorImpl(Supplier<A> supplier, BiConsumer<A, T> accumulator, BinaryOperator<A> combiner, Function<A, R> finisher) {
            this.supplier = supplier; this.accumulator = accumulator; this.combiner = combiner; this.finisher = finisher;
        }
        public BiConsumer<A, T> accumulator() { return accumulator; }
        public Supplier<A> supplier() { return supplier; }
        public BinaryOperator<A> combiner() { return combiner; }
        public Function<A, R> finisher() { return finisher; }
        public Set<Characteristics> characteristics() { return Collections.emptySet(); }
    }
    public static <T, C extends Collection<T>> Collector<T, ?, C> toCollection(Supplier<C> collectionFactory) {
        return new CollectorImpl<T, C, C>(collectionFactory, (c, t) -> c.add(t), (r1, r2) -> { r1.addAll(r2); return r1; }, c -> c);
    }
    public static <T> Collector<T, ?, List<T>> toList() {
        return new CollectorImpl<T, List<T>, List<T>>(() -> new ArrayList<T>(), (l, t) -> l.add(t), (a, b) -> { a.addAll(b); return a; }, l -> l);
    }
    public static <T> Collector<T, ?, List<T>> toUnmodifiableList() {
        return new CollectorImpl<T, List<T>, List<T>>(() -> new ArrayList<T>(), (l, t) -> l.add(t), (a, b) -> { a.addAll(b); return a; }, l -> List.copyOf(l));
    }
    public static <T> Collector<T, ?, Set<T>> toSet() {
        return new CollectorImpl<T, Set<T>, Set<T>>(() -> new HashSet<T>(), (l, t) -> l.add(t), (a, b) -> { a.addAll(b); return a; }, l -> l);
    }
    public static <T> Collector<T, ?, Set<T>> toUnmodifiableSet() {
        return new CollectorImpl<T, Set<T>, Set<T>>(() -> new HashSet<T>(), (l, t) -> l.add(t), (a, b) -> { a.addAll(b); return a; }, l -> Collections.unmodifiableSet(l));
    }
    public static Collector<CharSequence, ?, String> joining() {
        return new CollectorImpl<CharSequence, StringBuilder, String>(() -> new StringBuilder(), (sb, s) -> sb.append(s), (a, b) -> a.append(b), sb -> sb.toString());
    }
    public static Collector<CharSequence, ?, String> joining(CharSequence delimiter) { return joining(delimiter, "", ""); }
    public static Collector<CharSequence, ?, String> joining(CharSequence delimiter, CharSequence prefix, CharSequence suffix) {
        return new CollectorImpl<CharSequence, StringJoiner, String>(() -> new StringJoiner(delimiter, prefix, suffix), (j, s) -> j.add(s), (a, b) -> a, j -> j.toString());
    }
    public static <T, U, A, R> Collector<T, ?, R> mapping(Function<? super T, ? extends U> mapper, Collector<? super U, A, R> downstream) {
        BiConsumer<A, ? super U> acc = downstream.accumulator();
        return new CollectorImpl<T, A, R>(downstream.supplier(), (r, t) -> acc.accept(r, mapper.apply(t)), downstream.combiner(), downstream.finisher());
    }
    public static <T, U, A, R> Collector<T, ?, R> flatMapping(Function<? super T, ? extends Stream<? extends U>> mapper, Collector<? super U, A, R> downstream) {
        BiConsumer<A, ? super U> acc = downstream.accumulator();
        return new CollectorImpl<T, A, R>(downstream.supplier(), (r, t) -> { Stream<? extends U> s = mapper.apply(t); if (s != null) s.forEach(u -> acc.accept(r, u)); }, downstream.combiner(), downstream.finisher());
    }
    public static <T, A, R> Collector<T, ?, R> filtering(Predicate<? super T> predicate, Collector<? super T, A, R> downstream) {
        BiConsumer<A, ? super T> acc = downstream.accumulator();
        return new CollectorImpl<T, A, R>(downstream.supplier(), (r, t) -> { if (predicate.test(t)) acc.accept(r, t); }, downstream.combiner(), downstream.finisher());
    }
    public static <T, A, R, RR> Collector<T, A, RR> collectingAndThen(Collector<T, A, R> downstream, Function<R, RR> finisher) {
        return new CollectorImpl<T, A, RR>(downstream.supplier(), downstream.accumulator(), downstream.combiner(), downstream.finisher().andThen(finisher));
    }
    public static <T> Collector<T, ?, Long> counting() {
        return new CollectorImpl<T, long[], Long>(() -> new long[1], (a, t) -> { a[0]++; }, (a, b) -> { a[0] += b[0]; return a; }, a -> a[0]);
    }
    public static <T> Collector<T, ?, Optional<T>> minBy(Comparator<? super T> comparator) {
        return reducing(BinaryOperator.minBy(comparator));
    }
    public static <T> Collector<T, ?, Optional<T>> maxBy(Comparator<? super T> comparator) {
        return reducing(BinaryOperator.maxBy(comparator));
    }
    public static <T> Collector<T, ?, Integer> summingInt(ToIntFunction<? super T> mapper) {
        return new CollectorImpl<T, int[], Integer>(() -> new int[1], (a, t) -> { a[0] += mapper.applyAsInt(t); }, (a, b) -> { a[0] += b[0]; return a; }, a -> a[0]);
    }
    public static <T> Collector<T, ?, Long> summingLong(ToLongFunction<? super T> mapper) {
        return new CollectorImpl<T, long[], Long>(() -> new long[1], (a, t) -> { a[0] += mapper.applyAsLong(t); }, (a, b) -> { a[0] += b[0]; return a; }, a -> a[0]);
    }
    public static <T> Collector<T, ?, Double> summingDouble(ToDoubleFunction<? super T> mapper) {
        return new CollectorImpl<T, double[], Double>(() -> new double[1], (a, t) -> { a[0] += mapper.applyAsDouble(t); }, (a, b) -> { a[0] += b[0]; return a; }, a -> a[0]);
    }
    public static <T> Collector<T, ?, Double> averagingInt(ToIntFunction<? super T> mapper) {
        return new CollectorImpl<T, long[], Double>(() -> new long[2], (a, t) -> { a[0] += mapper.applyAsInt(t); a[1]++; }, (a, b) -> a, a -> (a[1] == 0) ? 0.0d : (double) a[0] / a[1]);
    }
    public static <T> Collector<T, ?, Double> averagingLong(ToLongFunction<? super T> mapper) {
        return new CollectorImpl<T, long[], Double>(() -> new long[2], (a, t) -> { a[0] += mapper.applyAsLong(t); a[1]++; }, (a, b) -> a, a -> (a[1] == 0) ? 0.0d : (double) a[0] / a[1]);
    }
    public static <T> Collector<T, ?, Double> averagingDouble(ToDoubleFunction<? super T> mapper) {
        return new CollectorImpl<T, double[], Double>(() -> new double[2], (a, t) -> { a[0] += mapper.applyAsDouble(t); a[1]++; }, (a, b) -> a, a -> (a[1] == 0) ? 0.0d : a[0] / a[1]);
    }
    public static <T> Collector<T, ?, T> reducing(T identity, BinaryOperator<T> op) {
        return new CollectorImpl<T, Object[], T>(() -> new Object[] { identity }, (a, t) -> { a[0] = op.apply((T) a[0], t); }, (a, b) -> a, a -> (T) a[0]);
    }
    public static <T> Collector<T, ?, Optional<T>> reducing(BinaryOperator<T> op) {
        return new CollectorImpl<T, Object[], Optional<T>>(() -> new Object[2], (a, t) -> { if (a[1] == null) { a[0] = t; a[1] = Boolean.TRUE; } else a[0] = op.apply((T) a[0], t); }, (a, b) -> a, a -> a[1] == null ? Optional.<T>empty() : Optional.of((T) a[0]));
    }
    public static <T, U> Collector<T, ?, U> reducing(U identity, Function<? super T, ? extends U> mapper, BinaryOperator<U> op) {
        return new CollectorImpl<T, Object[], U>(() -> new Object[] { identity }, (a, t) -> { a[0] = op.apply((U) a[0], mapper.apply(t)); }, (a, b) -> a, a -> (U) a[0]);
    }
    public static <T, K> Collector<T, ?, Map<K, List<T>>> groupingBy(Function<? super T, ? extends K> classifier) {
        return groupingBy(classifier, toList());
    }
    public static <T, K, A, D> Collector<T, ?, Map<K, D>> groupingBy(Function<? super T, ? extends K> classifier, Collector<? super T, A, D> downstream) {
        return groupingBy(classifier, () -> new HashMap<K, D>(), downstream);
    }
    public static <T, K, D, A, M extends Map<K, D>> Collector<T, ?, M> groupingBy(Function<? super T, ? extends K> classifier, Supplier<M> mapFactory, Collector<? super T, A, D> downstream) {
        Supplier<A> downstreamSupplier = downstream.supplier();
        BiConsumer<A, ? super T> downstreamAccumulator = downstream.accumulator();
        BiConsumer<Map<K, A>, T> accumulator = (m, t) -> {
            K key = Objects.requireNonNull(classifier.apply(t), "element cannot be mapped to a null key");
            A container = m.computeIfAbsent(key, k -> downstreamSupplier.get());
            downstreamAccumulator.accept(container, t);
        };
        Supplier<Map<K, A>> mangledFactory = (Supplier<Map<K, A>>) (Supplier) mapFactory;
        Function<A, A> downstreamFinisher = (Function<A, A>) (Function) downstream.finisher();
        Function<Map<K, A>, M> finisher = intermediate -> {
            intermediate.replaceAll((k, v) -> downstreamFinisher.apply(v));
            return (M) intermediate;
        };
        return new CollectorImpl<T, Map<K, A>, M>(mangledFactory, accumulator, (a, b) -> a, finisher);
    }
    public static <T, K> Collector<T, ?, java.util.concurrent.ConcurrentMap<K, List<T>>> groupingByConcurrent(Function<? super T, ? extends K> classifier) {
        return groupingBy(classifier, () -> new java.util.concurrent.ConcurrentHashMap<K, List<T>>(), toList());
    }
    public static <T> Collector<T, ?, Map<Boolean, List<T>>> partitioningBy(Predicate<? super T> predicate) { return partitioningBy(predicate, toList()); }
    public static <T, D, A> Collector<T, ?, Map<Boolean, D>> partitioningBy(Predicate<? super T> predicate, Collector<? super T, A, D> downstream) {
        BiConsumer<A, ? super T> downstreamAccumulator = downstream.accumulator();
        Supplier<Object[]> sup = () -> new Object[] { downstream.supplier().get(), downstream.supplier().get() };
        BiConsumer<Object[], T> acc = (a, t) -> downstreamAccumulator.accept((A) a[predicate.test(t) ? 1 : 0], t);
        Function<Object[], Map<Boolean, D>> fin = a -> {
            Map<Boolean, D> m = new LinkedHashMap<>();
            m.put(false, downstream.finisher().apply((A) a[0]));
            m.put(true, downstream.finisher().apply((A) a[1]));
            return m;
        };
        return new CollectorImpl<T, Object[], Map<Boolean, D>>(sup, acc, (a, b) -> a, fin);
    }
    public static <T, K, U> Collector<T, ?, Map<K, U>> toMap(Function<? super T, ? extends K> keyMapper, Function<? super T, ? extends U> valueMapper) {
        return new CollectorImpl<T, Map<K, U>, Map<K, U>>(() -> new HashMap<K, U>(), (m, t) -> {
            K k = keyMapper.apply(t);
            U v = Objects.requireNonNull(valueMapper.apply(t));
            U u = m.putIfAbsent(k, v);
            if (u != null) throw new IllegalStateException("Duplicate key " + k + " (attempted merging values " + u + " and " + v + ")");
        }, (a, b) -> a, m -> m);
    }
    public static <T, K, U> Collector<T, ?, Map<K, U>> toUnmodifiableMap(Function<? super T, ? extends K> keyMapper, Function<? super T, ? extends U> valueMapper) {
        return collectingAndThen(toMap(keyMapper, valueMapper), m -> Collections.unmodifiableMap(m));
    }
    public static <T, K, U> Collector<T, ?, Map<K, U>> toMap(Function<? super T, ? extends K> keyMapper, Function<? super T, ? extends U> valueMapper, BinaryOperator<U> mergeFunction) {
        return toMap(keyMapper, valueMapper, mergeFunction, () -> new HashMap<K, U>());
    }
    public static <T, K, U, M extends Map<K, U>> Collector<T, ?, M> toMap(Function<? super T, ? extends K> keyMapper, Function<? super T, ? extends U> valueMapper, BinaryOperator<U> mergeFunction, Supplier<M> mapFactory) {
        return new CollectorImpl<T, M, M>(mapFactory, (m, t) -> m.merge(keyMapper.apply(t), valueMapper.apply(t), mergeFunction), (a, b) -> a, m -> m);
    }
    public static <T, K, U> Collector<T, ?, java.util.concurrent.ConcurrentMap<K, U>> toConcurrentMap(Function<? super T, ? extends K> keyMapper, Function<? super T, ? extends U> valueMapper) {
        return new CollectorImpl<T, java.util.concurrent.ConcurrentMap<K, U>, java.util.concurrent.ConcurrentMap<K, U>>(() -> new java.util.concurrent.ConcurrentHashMap<K, U>(), (m, t) -> m.put(keyMapper.apply(t), valueMapper.apply(t)), (a, b) -> a, m -> m);
    }
    public static <T> Collector<T, ?, IntSummaryStatistics> summarizingInt(ToIntFunction<? super T> mapper) {
        return new CollectorImpl<T, IntSummaryStatistics, IntSummaryStatistics>(() -> new IntSummaryStatistics(), (r, t) -> r.accept(mapper.applyAsInt(t)), (l, r) -> l, x -> x);
    }
    public static <T> Collector<T, ?, LongSummaryStatistics> summarizingLong(ToLongFunction<? super T> mapper) {
        return new CollectorImpl<T, LongSummaryStatistics, LongSummaryStatistics>(() -> new LongSummaryStatistics(), (r, t) -> r.accept(mapper.applyAsLong(t)), (l, r) -> l, x -> x);
    }
    public static <T> Collector<T, ?, DoubleSummaryStatistics> summarizingDouble(ToDoubleFunction<? super T> mapper) {
        return new CollectorImpl<T, DoubleSummaryStatistics, DoubleSummaryStatistics>(() -> new DoubleSummaryStatistics(), (r, t) -> r.accept(mapper.applyAsDouble(t)), (l, r) -> l, x -> x);
    }
    public static <T, R1, R2, R> Collector<T, ?, R> teeing(Collector<? super T, ?, R1> downstream1, Collector<? super T, ?, R2> downstream2, BiFunction<? super R1, ? super R2, R> merger) {
        Collector<T, Object, R1> d1 = (Collector<T, Object, R1>) downstream1;
        Collector<T, Object, R2> d2 = (Collector<T, Object, R2>) downstream2;
        return new CollectorImpl<T, Object[], R>(() -> new Object[] { d1.supplier().get(), d2.supplier().get() },
            (a, t) -> { d1.accumulator().accept(a[0], t); d2.accumulator().accept(a[1], t); },
            (a, b) -> a, a -> merger.apply(d1.finisher().apply(a[0]), d2.finisher().apply(a[1])));
    }
}
