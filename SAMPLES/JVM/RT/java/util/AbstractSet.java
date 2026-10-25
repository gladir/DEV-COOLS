package java.util;
public abstract class AbstractSet<E> extends AbstractCollection<E> implements Set<E> {
    protected AbstractSet() {}
    public boolean equals(Object o) {
        if (o == this) return true;
        if (!(o instanceof Set)) return false;
        Collection<?> c = (Collection<?>) o;
        if (c.size() != size()) return false;
        try { return containsAll(c); } catch (ClassCastException | NullPointerException unused) { return false; }
    }
    public int hashCode() {
        int h = 0;
        Iterator<E> i = iterator();
        while (i.hasNext()) { E obj = i.next(); if (obj != null) h += obj.hashCode(); }
        return h;
    }
    public boolean removeAll(Collection<?> c) {
        Objects.requireNonNull(c);
        boolean modified = false;
        if (size() > c.size()) { for (Object e : c) modified |= remove(e); }
        else { for (Iterator<?> i = iterator(); i.hasNext(); ) { if (c.contains(i.next())) { i.remove(); modified = true; } } }
        return modified;
    }
}
