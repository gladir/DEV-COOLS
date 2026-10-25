package java.util;
public class LongSummaryStatistics implements java.util.function.LongConsumer, java.util.function.IntConsumer {
    private long count;
    private long sum;
    private long min = Long.MAX_VALUE;
    private long max = Long.MIN_VALUE;
    public LongSummaryStatistics() { }
    public void accept(int value) { accept((long) value); }
    public void accept(long value) { ++count; sum += value; min = Math.min(min, value); max = Math.max(max, value); }
    public final long getCount() { return count; }
    public final long getSum() { return sum; }
    public final long getMin() { return min; }
    public final long getMax() { return max; }
    public final double getAverage() { return getCount() > 0 ? (double) getSum() / getCount() : 0.0d; }
    public String toString() {
        return String.format("%s{count=%d, sum=%d, min=%d, average=%f, max=%d}", "LongSummaryStatistics", getCount(), getSum(), getMin(), getAverage(), getMax());
    }
}
