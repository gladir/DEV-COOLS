package java.util;
import java.util.function.*;
public final class OptionalLong {
    private static final OptionalLong EMPTY = new OptionalLong();
    private final boolean isPresent;
    private final long value;
    private OptionalLong() { this.isPresent = false; this.value = 0; }
    public static OptionalLong empty() { return EMPTY; }
    private OptionalLong(long value) { this.isPresent = true; this.value = value; }
    public static OptionalLong of(long value) { return new OptionalLong(value); }
    public long getAsLong() { if (!isPresent) throw new NoSuchElementException("No value present"); return value; }
    public boolean isPresent() { return isPresent; }
    public boolean isEmpty() { return !isPresent; }
    public void ifPresent(LongConsumer action) { if (isPresent) action.accept(value); }
    public long orElse(long other) { return isPresent ? value : other; }
    public long orElseGet(LongSupplier supplier) { return isPresent ? value : supplier.getAsLong(); }
    public long orElseThrow() { if (!isPresent) throw new NoSuchElementException("No value present"); return value; }
    public String toString() { return isPresent ? ("OptionalLong[" + value + "]") : "OptionalLong.empty"; }
}
