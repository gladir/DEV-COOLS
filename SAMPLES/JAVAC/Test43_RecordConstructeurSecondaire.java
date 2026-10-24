import java.util.*;
import java.util.function.*;
public class Test43_RecordConstructeurSecondaire {
    record Impl<T, A, R>(Supplier<A> supplier, BiConsumer<A, T> acc, BinaryOperator<A> comb, Function<A, R> fin, Set<String> ch) {
        Impl(Supplier<A> supplier, BiConsumer<A, T> acc, BinaryOperator<A> comb, Set<String> ch) {
            this(supplier, acc, comb, castingIdentity(), ch);
        }
        @SuppressWarnings("unchecked")
        private static <I, R> Function<I, R> castingIdentity() { return i -> (R) i; }
    }
    static <T> Impl<T, ?, List<T>> toList() {
        return new Impl<>(ArrayList::new, List::add, (l, r) -> { l.addAll(r); return l; }, Set.of());
    }
    public static void main(String[] args) { System.out.println(toList().ch()); }
}
