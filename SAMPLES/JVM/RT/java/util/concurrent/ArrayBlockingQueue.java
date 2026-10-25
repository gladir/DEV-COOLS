package java.util.concurrent;
public class ArrayBlockingQueue<E> extends LinkedBlockingQueue<E> {
    private static final long serialVersionUID = -817911632652898426L;
    public ArrayBlockingQueue(int capacity) { super(capacity); }
    public ArrayBlockingQueue(int capacity, boolean fair) { super(capacity); }
}
