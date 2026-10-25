package java.util;
public abstract class EnumSet<E extends Enum<E>> extends AbstractSet<E> implements Cloneable, java.io.Serializable {
    private static final long serialVersionUID = 1009687484059888093L;
    final transient Class<E> elementType;
    final transient E[] universe;
    private static class SerializationProxy<E extends Enum<E>> implements java.io.Serializable {
        private static final long serialVersionUID = 362491234563181265L;
        private final Class<E> elementType;
        private final Enum<?>[] elements;
        SerializationProxy(EnumSet<E> set) {
            elementType = set.elementType;
            elements = set.toArray(new Enum<?>[0]);
        }
        private Object readResolve() {
            EnumSet<E> result = EnumSet.noneOf(elementType);
            for (Enum<?> e : elements) result.add((E) e);
            return result;
        }
    }
    Object writeReplace() { return new SerializationProxy<E>(this); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.InvalidObjectException {
        throw new java.io.InvalidObjectException("Proxy required");
    }
    EnumSet(Class<E> elementType, E[] universe) { this.elementType = elementType; this.universe = universe; }
    private static class Impl<E extends Enum<E>> extends EnumSet<E> {
        boolean[] has;
        int size;
        Impl(Class<E> t, E[] u) { super(t, u); has = new boolean[u.length]; }
        public int size() { return size; }
        public boolean contains(Object o) { return o instanceof Enum<?> e && e.getDeclaringClass() == elementType && has[e.ordinal()]; }
        public boolean add(E e) { int i = e.ordinal(); if (has[i]) return false; has[i] = true; size++; return true; }
        public boolean remove(Object o) { if (!contains(o)) return false; has[((Enum<?>) o).ordinal()] = false; size--; return true; }
        public void clear() { Arrays.fill(has, false); size = 0; }
        public Iterator<E> iterator() {
            return new Iterator<E>() {
                int idx = 0, last = -1;
                public boolean hasNext() { while (idx < has.length && !has[idx]) idx++; return idx < has.length; }
                public E next() { if (!hasNext()) throw new NoSuchElementException(); last = idx++; return universe[last]; }
                public void remove() { if (last < 0) throw new IllegalStateException(); if (has[last]) { has[last] = false; size--; } last = -1; }
            };
        }
    }
    public static <E extends Enum<E>> EnumSet<E> noneOf(Class<E> elementType) { return new Impl<E>(elementType, elementType.getEnumConstants()); }
    public static <E extends Enum<E>> EnumSet<E> allOf(Class<E> elementType) { EnumSet<E> r = noneOf(elementType); for (E e : r.universe) r.add(e); return r; }
    public static <E extends Enum<E>> EnumSet<E> copyOf(EnumSet<E> s) { EnumSet<E> r = noneOf(s.elementType); r.addAll(s); return r; }
    public static <E extends Enum<E>> EnumSet<E> copyOf(Collection<E> c) {
        if (c instanceof EnumSet) return copyOf((EnumSet<E>) c);
        if (c.isEmpty()) throw new IllegalArgumentException("Collection is empty");
        Iterator<E> i = c.iterator();
        E first = i.next();
        EnumSet<E> result = EnumSet.of(first);
        while (i.hasNext()) result.add(i.next());
        return result;
    }
    public static <E extends Enum<E>> EnumSet<E> complementOf(EnumSet<E> s) { EnumSet<E> r = noneOf(s.elementType); for (E e : s.universe) if (!s.contains(e)) r.add(e); return r; }
    public static <E extends Enum<E>> EnumSet<E> of(E e) { EnumSet<E> r = noneOf(e.getDeclaringClass()); r.add(e); return r; }
    public static <E extends Enum<E>> EnumSet<E> of(E e1, E e2) { EnumSet<E> r = of(e1); r.add(e2); return r; }
    public static <E extends Enum<E>> EnumSet<E> of(E e1, E e2, E e3) { EnumSet<E> r = of(e1, e2); r.add(e3); return r; }
    public static <E extends Enum<E>> EnumSet<E> of(E e1, E e2, E e3, E e4) { EnumSet<E> r = of(e1, e2, e3); r.add(e4); return r; }
    public static <E extends Enum<E>> EnumSet<E> of(E e1, E e2, E e3, E e4, E e5) { EnumSet<E> r = of(e1, e2, e3, e4); r.add(e5); return r; }
    public static <E extends Enum<E>> EnumSet<E> of(E first, E... rest) { EnumSet<E> r = of(first); for (E e : rest) r.add(e); return r; }
    public static <E extends Enum<E>> EnumSet<E> range(E from, E to) {
        if (from.compareTo(to) > 0) throw new IllegalArgumentException(from + " > " + to);
        EnumSet<E> r = noneOf(from.getDeclaringClass());
        for (E e : r.universe) if (e.ordinal() >= from.ordinal() && e.ordinal() <= to.ordinal()) r.add(e);
        return r;
    }
    public EnumSet<E> clone() { return copyOf(this); }
}
