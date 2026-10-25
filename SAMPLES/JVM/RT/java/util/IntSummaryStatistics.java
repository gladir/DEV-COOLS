package java.util;
public class IntSummaryStatistics implements java.util.function.IntConsumer {
    private long count;
    private long sum;
    private int min = Integer.MAX_VALUE;
    private int max = Integer.MIN_VALUE;
    public IntSummaryStatistics() { }
    public void accept(int value) { ++count; sum += value; min = Math.min(min, value); max = Math.max(max, value); }
    public void combine(IntSummaryStatistics other) { count += other.count; sum += other.sum; min = Math.min(min, other.min); max = Math.max(max, other.max); }
    public final long getCount() { return count; }
    public final long getSum() { return sum; }
    public final int getMin() { return min; }
    public final int getMax() { return max; }
    public final double getAverage() { return getCount() > 0 ? (double) getSum() / getCount() : 0.0d; }
    public String toString() {
        return String.format("%s{count=%d, sum=%d, min=%d, average=%f, max=%d}", "IntSummaryStatistics", getCount(), getSum(), getMin(), getAverage(), getMax());
    }
}
