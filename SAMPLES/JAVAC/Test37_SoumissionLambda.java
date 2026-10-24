import java.util.concurrent.*;
public class Test37_SoumissionLambda {
    static void work(int n) { System.out.println("work " + n); }
    static int calc(int n) { return n * 2; }
    public static void main(String[] args) throws Exception {
        ExecutorService ex = Executors.newSingleThreadExecutor();
        Future<?> a = ex.submit(() -> work(1));
        Future<Integer> b = ex.submit(() -> calc(21));
        Future<?> c = ex.submit(() -> System.out.println("hi"));
        a.get(); c.get();
        System.out.println(b.get());
        ex.shutdown();
    }
}
