package java.util.concurrent;
public abstract class RecursiveAction extends ForkJoinTask<Void> {
    private static final long serialVersionUID = 5232453952276485070L;
    protected abstract void compute();
    public final Void getRawResult() { return null; }
    protected boolean exec0() { compute(); return true; }
    Void result0() { return null; }
}
