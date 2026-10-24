package java.util;
public class Vector<E> extends ArrayList<E> {
    public Vector() { super(); }
    public Vector(int n) { super(n); }
    public Vector(Collection<? extends E> c) { super(c); }
    public void addElement(E e) { add(e); }
    public E elementAt(int i) { return get(i); }
    public E firstElement() { if (isEmpty()) throw new NoSuchElementException(); return get(0); }
    public E lastElement() { if (isEmpty()) throw new NoSuchElementException(); return get(size() - 1); }
    public void removeAllElements() { clear(); }
    public boolean removeElement(Object o) { return remove(o); }
    public void removeElementAt(int i) { remove(i); }
    public void insertElementAt(E e, int i) { add(i, e); }
    public void setElementAt(E e, int i) { set(i, e); }
    public Enumeration<E> elements() {
        final Iterator<E> it = iterator();
        return new Enumeration<E>() {
            public boolean hasMoreElements() { return it.hasNext(); }
            public E nextElement() { return it.next(); }
        };
    }
}
