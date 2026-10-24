package java.util.concurrent;
public abstract class RecursiveTask<V> extends ForkJoinTask<V> {
    private static final long serialVersionUID = 5232453952276485270L;
    V result;
    protected abstract V compute();
    public final V getRawResult() { return result; }
    protected boolean exec0() { result = compute(); return true; }
    V result0() { return result; }
}
