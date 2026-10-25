package java.util;
import java.util.function.*;
public interface Map<K, V> {
    int size();
    boolean isEmpty();
    boolean containsKey(Object key);
    boolean containsValue(Object value);
    V get(Object key);
    V put(K key, V value);
    V remove(Object key);
    void putAll(Map<? extends K, ? extends V> m);
    void clear();
    Set<K> keySet();
    Collection<V> values();
    Set<Map.Entry<K, V>> entrySet();
    interface Entry<K, V> {
        K getKey();
        V getValue();
        V setValue(V value);
        boolean equals(Object o);
        int hashCode();
        static <K extends Comparable<? super K>, V> Comparator<Map.Entry<K, V>> comparingByKey() { return (c1, c2) -> c1.getKey().compareTo(c2.getKey()); }
        static <K, V extends Comparable<? super V>> Comparator<Map.Entry<K, V>> comparingByValue() { return (c1, c2) -> c1.getValue().compareTo(c2.getValue()); }
        static <K, V> Comparator<Map.Entry<K, V>> comparingByKey(Comparator<? super K> cmp) { return (c1, c2) -> cmp.compare(c1.getKey(), c2.getKey()); }
        static <K, V> Comparator<Map.Entry<K, V>> comparingByValue(Comparator<? super V> cmp) { return (c1, c2) -> cmp.compare(c1.getValue(), c2.getValue()); }
    }
    boolean equals(Object o);
    int hashCode();
    default V getOrDefault(Object key, V defaultValue) {
        V v;
        return (((v = get(key)) != null) || containsKey(key)) ? v : defaultValue;
    }
    default void forEach(BiConsumer<? super K, ? super V> action) {
        for (Map.Entry<K, V> entry : entrySet()) action.accept(entry.getKey(), entry.getValue());
    }
    default void replaceAll(BiFunction<? super K, ? super V, ? extends V> function) {
        for (Map.Entry<K, V> entry : entrySet()) entry.setValue(function.apply(entry.getKey(), entry.getValue()));
    }
    default V putIfAbsent(K key, V value) {
        V v = get(key);
        if (v == null) v = put(key, value);
        return v;
    }
    default boolean remove(Object key, Object value) {
        Object curValue = get(key);
        if (!Objects.equals(curValue, value) || (curValue == null && !containsKey(key))) return false;
        remove(key);
        return true;
    }
    default boolean replace(K key, V oldValue, V newValue) {
        Object curValue = get(key);
        if (!Objects.equals(curValue, oldValue) || (curValue == null && !containsKey(key))) return false;
        put(key, newValue);
        return true;
    }
    default V replace(K key, V value) {
        V curValue;
        if (((curValue = get(key)) != null) || containsKey(key)) curValue = put(key, value);
        return curValue;
    }
    default V computeIfAbsent(K key, Function<? super K, ? extends V> mappingFunction) {
        V v;
        if ((v = get(key)) == null) {
            V newValue;
            if ((newValue = mappingFunction.apply(key)) != null) { put(key, newValue); return newValue; }
        }
        return v;
    }
    default V computeIfPresent(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) {
        V oldValue;
        if ((oldValue = get(key)) != null) {
            V newValue = remappingFunction.apply(key, oldValue);
            if (newValue != null) { put(key, newValue); return newValue; }
            else { remove(key); return null; }
        }
        return null;
    }
    default V compute(K key, BiFunction<? super K, ? super V, ? extends V> remappingFunction) {
        V oldValue = get(key);
        V newValue = remappingFunction.apply(key, oldValue);
        if (newValue == null) {
            if (oldValue != null || containsKey(key)) { remove(key); return null; }
            else return null;
        } else { put(key, newValue); return newValue; }
    }
    default V merge(K key, V value, BiFunction<? super V, ? super V, ? extends V> remappingFunction) {
        Objects.requireNonNull(value);
        V oldValue = get(key);
        V newValue = (oldValue == null) ? value : remappingFunction.apply(oldValue, value);
        if (newValue == null) remove(key); else put(key, newValue);
        return newValue;
    }
    static <K, V> Map<K, V> of() { return ImmutableCollections.mapOf(); }
    static <K, V> Map<K, V> of(K k1, V v1) { return ImmutableCollections.mapOf(k1, v1); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2) { return ImmutableCollections.mapOf(k1, v1, k2, v2); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4, K k5, V v5) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4, K k5, V v5, K k6, V v6) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4, K k5, V v5, K k6, V v6, K k7, V v7) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4, K k5, V v5, K k6, V v6, K k7, V v7, K k8, V v8) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4, K k5, V v5, K k6, V v6, K k7, V v7, K k8, V v8, K k9, V v9) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9); }
    static <K, V> Map<K, V> of(K k1, V v1, K k2, V v2, K k3, V v3, K k4, V v4, K k5, V v5, K k6, V v6, K k7, V v7, K k8, V v8, K k9, V v9, K k10, V v10) { return ImmutableCollections.mapOf(k1, v1, k2, v2, k3, v3, k4, v4, k5, v5, k6, v6, k7, v7, k8, v8, k9, v9, k10, v10); }
    static <K, V> Map<K, V> ofEntries(Map.Entry<? extends K, ? extends V>... entries) {
        Object[] kv = new Object[entries.length * 2];
        for (int i = 0; i < entries.length; i++) { kv[2 * i] = entries[i].getKey(); kv[2 * i + 1] = entries[i].getValue(); }
        return ImmutableCollections.mapOf(kv);
    }
    static <K, V> Map.Entry<K, V> entry(K k, V v) { return new AbstractMap.SimpleImmutableEntry<>(Objects.requireNonNull(k), Objects.requireNonNull(v)); }
    static <K, V> Map<K, V> copyOf(Map<? extends K, ? extends V> map) {
        Object[] kv = new Object[map.size() * 2];
        int i = 0;
        for (Map.Entry<? extends K, ? extends V> e : map.entrySet()) { kv[i++] = e.getKey(); kv[i++] = e.getValue(); }
        return ImmutableCollections.mapOf(kv);
    }
}
