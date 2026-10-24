package java.util.concurrent;
public class ScheduledThreadPoolExecutor extends ThreadPoolExecutor {
    public ScheduledThreadPoolExecutor(int core) { super(core, 1000, null); }
}
