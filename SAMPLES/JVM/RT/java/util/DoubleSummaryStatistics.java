package java.util;
public class DoubleSummaryStatistics implements java.util.function.DoubleConsumer {
    private long count;
    private double sum;
    private double min = Double.POSITIVE_INFINITY;
    private double max = Double.NEGATIVE_INFINITY;
    public DoubleSummaryStatistics() { }
    public void accept(double value) { ++count; sum += value; min = Math.min(min, value); max = Math.max(max, value); }
    public final long getCount() { return count; }
    public final double getSum() { return sum; }
    public final double getMin() { return min; }
    public final double getMax() { return max; }
    public final double getAverage() { return getCount() > 0 ? getSum() / getCount() : 0.0d; }
    public String toString() {
        return String.format("%s{count=%d, sum=%f, min=%f, average=%f, max=%f}", "DoubleSummaryStatistics", getCount(), getSum(), getMin(), getAverage(), getMax());
    }
}
