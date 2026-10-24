package java.util.concurrent;
import java.util.*;
public class ConcurrentSkipListMap<K, V> extends TreeMap<K, V> implements ConcurrentMap<K, V> {
    private static final long serialVersionUID = -8627078645895051609L;
    public ConcurrentSkipListMap() { }
    public ConcurrentSkipListMap(Comparator<? super K> c) { super(c); }
}
