package javax.swing;
import java.util.*;
public class DefaultListModel<E> extends AbstractListModel<E> {
    private ArrayList<E> delegate = new ArrayList<>();
    public int getSize() { return delegate.size(); }
    public E getElementAt(int index) { return delegate.get(index); }
    public void copyInto(Object[] anArray) { for (int i = 0; i < delegate.size(); i++) anArray[i] = delegate.get(i); }
    public void trimToSize() { delegate.trimToSize(); }
    public void ensureCapacity(int minCapacity) { delegate.ensureCapacity(minCapacity); }
    public void setSize(int newSize) {
        int oldSize = delegate.size();
        if (newSize < oldSize) {
            while (delegate.size() > newSize) delegate.remove(delegate.size() - 1);
            fireIntervalRemoved(this, newSize, oldSize - 1);
        } else if (newSize > oldSize) {
            while (delegate.size() < newSize) delegate.add(null);
            fireIntervalAdded(this, oldSize, newSize - 1);
        }
    }
    public int capacity() { return Math.max(10, delegate.size()); }
    public int size() { return delegate.size(); }
    public boolean isEmpty() { return delegate.isEmpty(); }
    public Enumeration<E> elements() { return Collections.enumeration(new ArrayList<>(delegate)); }
    public boolean contains(Object elem) { return delegate.contains(elem); }
    public int indexOf(Object elem) { return delegate.indexOf(elem); }
    public int indexOf(Object elem, int index) {
        for (int i = index; i < delegate.size(); i++) if (Objects.equals(elem, delegate.get(i))) return i;
        return -1;
    }
    public int lastIndexOf(Object elem) { return delegate.lastIndexOf(elem); }
    public int lastIndexOf(Object elem, int index) {
        for (int i = index; i >= 0; i--) if (Objects.equals(elem, delegate.get(i))) return i;
        return -1;
    }
    public E elementAt(int index) { return delegate.get(index); }
    public E firstElement() { if (delegate.isEmpty()) throw new NoSuchElementException(); return delegate.get(0); }
    public E lastElement() { if (delegate.isEmpty()) throw new NoSuchElementException(); return delegate.get(delegate.size() - 1); }
    public void setElementAt(E element, int index) { delegate.set(index, element); fireContentsChanged(this, index, index); }
    public void removeElementAt(int index) { delegate.remove(index); fireIntervalRemoved(this, index, index); }
    public void insertElementAt(E element, int index) { delegate.add(index, element); fireIntervalAdded(this, index, index); }
    public void addElement(E element) { int index = delegate.size(); delegate.add(element); fireIntervalAdded(this, index, index); }
    public boolean removeElement(Object obj) {
        int index = indexOf(obj);
        boolean rv = index >= 0;
        if (rv) removeElementAt(index);
        return rv;
    }
    public void removeAllElements() {
        int index1 = delegate.size() - 1;
        delegate.clear();
        if (index1 >= 0) fireIntervalRemoved(this, 0, index1);
    }
    public String toString() { return delegate.toString(); }
    public Object[] toArray() { return delegate.toArray(); }
    public E get(int index) { return delegate.get(index); }
    public E set(int index, E element) { E rv = delegate.get(index); delegate.set(index, element); fireContentsChanged(this, index, index); return rv; }
    public void add(int index, E element) { delegate.add(index, element); fireIntervalAdded(this, index, index); }
    public E remove(int index) { E rv = delegate.remove(index); fireIntervalRemoved(this, index, index); return rv; }
    public void clear() {
        int index1 = delegate.size() - 1;
        delegate.clear();
        if (index1 >= 0) fireIntervalRemoved(this, 0, index1);
    }
    public void removeRange(int fromIndex, int toIndex) {
        if (fromIndex > toIndex) throw new IllegalArgumentException("fromIndex must be <= toIndex");
        for (int i = toIndex; i >= fromIndex; i--) delegate.remove(i);
        fireIntervalRemoved(this, fromIndex, toIndex);
    }
    public void addAll(Collection<? extends E> c) {
        if (c.isEmpty()) return;
        int startIndex = delegate.size();
        delegate.addAll(c);
        fireIntervalAdded(this, startIndex, delegate.size() - 1);
    }
    public void addAll(int index, Collection<? extends E> c) {
        if (index < 0 || index > delegate.size()) throw new ArrayIndexOutOfBoundsException(index + " > " + delegate.size());
        if (c.isEmpty()) return;
        delegate.addAll(index, c);
        fireIntervalAdded(this, index, index + c.size() - 1);
    }
}
