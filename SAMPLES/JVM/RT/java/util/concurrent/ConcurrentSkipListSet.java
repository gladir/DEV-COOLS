package java.util.concurrent;
import java.util.*;
public class ConcurrentSkipListSet<E> extends TreeSet<E> {
    private static final long serialVersionUID = -2479143111061671589L;
    public ConcurrentSkipListSet() { }
    public ConcurrentSkipListSet(Comparator<? super E> c) { super(c); }
}
