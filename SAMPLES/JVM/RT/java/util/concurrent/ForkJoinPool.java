package java.util.concurrent;
public class ForkJoinPool extends ThreadPoolExecutor {
    private static ForkJoinPool common;
    public ForkJoinPool() { super(4, 4, null); }
    public ForkJoinPool(int n) { super(n, n, null); }
    public static ForkJoinPool commonPool() { if (common == null) common = new ForkJoinPool(); return common; }
    public <T> T invoke(ForkJoinTask<T> task) { return task.invoke(); }
    public int getParallelism() { return 4; }
    public static int getCommonPoolParallelism() { return 3; }
}
