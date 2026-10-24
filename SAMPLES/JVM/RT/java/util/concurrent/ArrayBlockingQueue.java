package java.util.concurrent;
public class ArrayBlockingQueue<E> extends LinkedBlockingQueue<E> {
    public ArrayBlockingQueue(int capacity) { super(capacity); }
    public ArrayBlockingQueue(int capacity, boolean fair) { super(capacity); }
}
