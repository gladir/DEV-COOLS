package java.util;
import java.util.function.*;
public final class OptionalInt {
    private static final OptionalInt EMPTY = new OptionalInt();
    private final boolean isPresent;
    private final int value;
    private OptionalInt() { this.isPresent = false; this.value = 0; }
    public static OptionalInt empty() { return EMPTY; }
    private OptionalInt(int value) { this.isPresent = true; this.value = value; }
    public static OptionalInt of(int value) { return new OptionalInt(value); }
    public int getAsInt() { if (!isPresent) throw new NoSuchElementException("No value present"); return value; }
    public boolean isPresent() { return isPresent; }
    public boolean isEmpty() { return !isPresent; }
    public void ifPresent(IntConsumer action) { if (isPresent) action.accept(value); }
    public void ifPresentOrElse(IntConsumer action, Runnable emptyAction) { if (isPresent) action.accept(value); else emptyAction.run(); }
    public int orElse(int other) { return isPresent ? value : other; }
    public int orElseGet(IntSupplier supplier) { return isPresent ? value : supplier.getAsInt(); }
    public int orElseThrow() { if (!isPresent) throw new NoSuchElementException("No value present"); return value; }
    public <X extends Throwable> int orElseThrow(Supplier<? extends X> s) throws X { if (isPresent) return value; else throw s.get(); }
    public boolean equals(Object obj) { return obj instanceof OptionalInt o && (isPresent && o.isPresent ? value == o.value : isPresent == o.isPresent); }
    public int hashCode() { return isPresent ? Integer.hashCode(value) : 0; }
    public String toString() { return isPresent ? ("OptionalInt[" + value + "]") : "OptionalInt.empty"; }
}
