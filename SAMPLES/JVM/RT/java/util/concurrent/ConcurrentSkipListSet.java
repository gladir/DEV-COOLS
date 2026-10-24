package java.util.concurrent;
import java.util.*;
public class ConcurrentSkipListSet<E> extends TreeSet<E> {
    public ConcurrentSkipListSet() { }
    public ConcurrentSkipListSet(Comparator<? super E> c) { super(c); }
}
