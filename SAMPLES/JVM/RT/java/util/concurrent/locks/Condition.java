package java.util.concurrent.locks;
import java.util.concurrent.TimeUnit;
public interface Condition {
    void await() throws InterruptedException;
    boolean await(long time, TimeUnit unit) throws InterruptedException;
    long awaitNanos(long nanos) throws InterruptedException;
    void signal();
    void signalAll();
}
