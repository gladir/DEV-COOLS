package java.util.concurrent;
import java.util.*;
import java.util.function.*;
public class ConcurrentHashMap<K, V> extends AbstractMap<K, V> implements ConcurrentMap<K, V> {
    private final HashMap<K, V> m = new HashMap<>();
    public ConcurrentHashMap() { }
    public ConcurrentHashMap(int cap) { }
    public ConcurrentHashMap(int cap, float lf) { }
    public ConcurrentHashMap(int cap, float lf, int cl) { }
    public ConcurrentHashMap(Map<? extends K, ? extends V> o) { putAll(o); }
    public synchronized int size() { return m.size(); }
    public synchronized boolean isEmpty() { return m.isEmpty(); }
    public synchronized V get(Object k) { if (k == null) throw new NullPointerException(); return m.get(k); }
    public synchronized boolean containsKey(Object k) { if (k == null) throw new NullPointerException(); return m.containsKey(k); }
    public synchronized boolean containsValue(Object v) { return m.containsValue(v); }
    public synchronized V put(K k, V v) { if (k == null || v == null) throw new NullPointerException(); return m.put(k, v); }
    public synchronized V remove(Object k) { if (k == null) throw new NullPointerException(); return m.remove(k); }
    public synchronized void clear() { m.clear(); }
    public synchronized V putIfAbsent(K k, V v) { if (k == null || v == null) throw new NullPointerException(); return m.putIfAbsent(k, v); }
    public synchronized boolean remove(Object k, Object v) { return m.remove(k, v); }
    public synchronized boolean replace(K k, V o, V n) { return m.replace(k, o, n); }
    public synchronized V replace(K k, V v) { return m.replace(k, v); }
    public synchronized V getOrDefault(Object k, V d) { V v = m.get(k); return v == null ? d : v; }
    public synchronized V computeIfAbsent(K k, Function<? super K, ? extends V> f) { return m.computeIfAbsent(k, f); }
    public synchronized V computeIfPresent(K k, BiFunction<? super K, ? super V, ? extends V> f) { return m.computeIfPresent(k, f); }
    public synchronized V compute(K k, BiFunction<? super K, ? super V, ? extends V> f) { return m.compute(k, f); }
    public synchronized V merge(K k, V v, BiFunction<? super V, ? super V, ? extends V> f) { return m.merge(k, v, f); }
    public synchronized void forEach(BiConsumer<? super K, ? super V> a) { for (Map.Entry<K, V> e : new ArrayList<>(m.entrySet())) a.accept(e.getKey(), e.getValue()); }
    public synchronized Set<Map.Entry<K, V>> entrySet() { return new LinkedHashSet<>(m.entrySet()); }
    public synchronized Set<K> keySet() { return new LinkedHashSet<>(m.keySet()); }
    public synchronized Collection<V> values() { return new ArrayList<>(m.values()); }
    public static <T> Set<T> newKeySet() { return Collections.synchronizedSet(new HashSet<T>()); }
    public long mappingCount() { return size(); }
    public synchronized String toString() { return m.toString(); }
}
