package java.util;
public interface PrimitiveIterator<T, T_CONS> extends Iterator<T> {
    public static interface OfInt extends PrimitiveIterator<Integer, java.util.function.IntConsumer> { int nextInt(); }
    public static interface OfLong extends PrimitiveIterator<Long, java.util.function.LongConsumer> { long nextLong(); }
    public static interface OfDouble extends PrimitiveIterator<Double, java.util.function.DoubleConsumer> { double nextDouble(); }
}
