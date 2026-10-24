package java.util.concurrent;
import java.util.*;
public class ConcurrentSkipListMap<K, V> extends TreeMap<K, V> implements ConcurrentMap<K, V> {
    public ConcurrentSkipListMap() { }
    public ConcurrentSkipListMap(Comparator<? super K> c) { super(c); }
}
