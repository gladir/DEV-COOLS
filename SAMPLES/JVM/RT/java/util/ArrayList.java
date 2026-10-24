package java.util;
import java.util.function.*;
public class ArrayList<E> extends AbstractList<E> implements List<E>, RandomAccess, Cloneable, java.io.Serializable {
    transient Object[] elementData;
    private int size;
    public ArrayList(int initialCapacity) {
        if (initialCapacity < 0) throw new IllegalArgumentException("Illegal Capacity: " + initialCapacity);
        elementData = new Object[initialCapacity];
    }
    public ArrayList() { elementData = new Object[10]; }
    public ArrayList(Collection<? extends E> c) {
        Object[] a = c.toArray();
        size = a.length;
        elementData = a.length == 0 ? new Object[10] : a;
        if (elementData == a && a.getClass() != Object[].class) elementData = Arrays.copyOf(a, size, Object[].class);
    }
    public void trimToSize() { modCount++; }
    public void ensureCapacity(int minCapacity) { if (minCapacity > elementData.length) grow(minCapacity); }
    private void grow(int minCapacity) {
        int n = elementData.length;
        int nc = n + (n >> 1);
        if (nc < minCapacity) nc = minCapacity;
        if (nc < 10) nc = 10;
        elementData = Arrays.copyOf(elementData, nc);
    }
    public int size() { return size; }
    public boolean isEmpty() { return size == 0; }
    public boolean contains(Object o) { return indexOf(o) >= 0; }
    public int indexOf(Object o) {
        if (o == null) { for (int i = 0; i < size; i++) if (elementData[i] == null) return i; }
        else { for (int i = 0; i < size; i++) if (o.equals(elementData[i])) return i; }
        return -1;
    }
    public int lastIndexOf(Object o) {
        if (o == null) { for (int i = size - 1; i >= 0; i--) if (elementData[i] == null) return i; }
        else { for (int i = size - 1; i >= 0; i--) if (o.equals(elementData[i])) return i; }
        return -1;
    }
    public Object clone() { ArrayList<E> v = new ArrayList<>(this); return v; }
    public Object[] toArray() { return Arrays.copyOf(elementData, size); }
    public <T> T[] toArray(T[] a) {
        if (a.length < size) return (T[]) Arrays.copyOf(elementData, size, a.getClass());
        System.arraycopy(elementData, 0, a, 0, size);
        if (a.length > size) a[size] = null;
        return a;
    }
    public E get(int index) { Objects.checkIndex(index, size); return (E) elementData[index]; }
    public E getFirst() { if (size == 0) throw new NoSuchElementException(); return (E) elementData[0]; }
    public E getLast() { if (size == 0) throw new NoSuchElementException(); return (E) elementData[size - 1]; }
    public E set(int index, E element) {
        Objects.checkIndex(index, size);
        E oldValue = (E) elementData[index];
        elementData[index] = element;
        return oldValue;
    }
    public boolean add(E e) {
        modCount++;
        if (size == elementData.length) grow(size + 1);
        elementData[size++] = e;
        return true;
    }
    public void add(int index, E element) {
        if (index > size || index < 0) throw new IndexOutOfBoundsException("Index: " + index + ", Size: " + size);
        modCount++;
        if (size == elementData.length) grow(size + 1);
        System.arraycopy(elementData, index, elementData, index + 1, size - index);
        elementData[index] = element;
        size++;
    }
    public E remove(int index) {
        Objects.checkIndex(index, size);
        modCount++;
        E oldValue = (E) elementData[index];
        int numMoved = size - index - 1;
        if (numMoved > 0) System.arraycopy(elementData, index + 1, elementData, index, numMoved);
        elementData[--size] = null;
        return oldValue;
    }
    public boolean remove(Object o) {
        int i = indexOf(o);
        if (i < 0) return false;
        remove(i);
        return true;
    }
    public void clear() {
        modCount++;
        for (int i = 0; i < size; i++) elementData[i] = null;
        size = 0;
    }
    public boolean addAll(Collection<? extends E> c) {
        Object[] a = c.toArray();
        modCount++;
        int numNew = a.length;
        if (numNew == 0) return false;
        if (size + numNew > elementData.length) grow(size + numNew);
        System.arraycopy(a, 0, elementData, size, numNew);
        size += numNew;
        return true;
    }
    public boolean addAll(int index, Collection<? extends E> c) {
        if (index > size || index < 0) throw new IndexOutOfBoundsException("Index: " + index + ", Size: " + size);
        Object[] a = c.toArray();
        modCount++;
        int numNew = a.length;
        if (numNew == 0) return false;
        if (size + numNew > elementData.length) grow(size + numNew);
        int numMoved = size - index;
        if (numMoved > 0) System.arraycopy(elementData, index, elementData, index + numNew, numMoved);
        System.arraycopy(a, 0, elementData, index, numNew);
        size += numNew;
        return true;
    }
    protected void removeRange(int fromIndex, int toIndex) {
        if (fromIndex > toIndex) throw new IndexOutOfBoundsException("From Index: " + fromIndex + " > To Index: " + toIndex);
        modCount++;
        System.arraycopy(elementData, toIndex, elementData, fromIndex, size - toIndex);
        int newSize = size - (toIndex - fromIndex);
        for (int i = newSize; i < size; i++) elementData[i] = null;
        size = newSize;
    }
    public boolean removeAll(Collection<?> c) { Objects.requireNonNull(c); return batchRemove(c, false); }
    public boolean retainAll(Collection<?> c) { Objects.requireNonNull(c); return batchRemove(c, true); }
    private boolean batchRemove(Collection<?> c, boolean complement) {
        int w = 0;
        for (int r = 0; r < size; r++) if (c.contains(elementData[r]) == complement) elementData[w++] = elementData[r];
        boolean modified = w != size;
        if (modified) {
            modCount++;
            for (int i = w; i < size; i++) elementData[i] = null;
            size = w;
        }
        return modified;
    }
    public boolean removeIf(Predicate<? super E> filter) {
        Objects.requireNonNull(filter);
        int w = 0;
        int expected = modCount;
        boolean[] del = new boolean[size];
        boolean any = false;
        for (int i = 0; i < size; i++) { if (filter.test((E) elementData[i])) { del[i] = true; any = true; } }
        if (modCount != expected) throw new ConcurrentModificationException();
        if (!any) return false;
        for (int i = 0; i < size; i++) if (!del[i]) elementData[w++] = elementData[i];
        for (int i = w; i < size; i++) elementData[i] = null;
        size = w;
        modCount++;
        return true;
    }
    public void forEach(Consumer<? super E> action) {
        Objects.requireNonNull(action);
        final int expectedModCount = modCount;
        final int size = this.size;
        for (int i = 0; modCount == expectedModCount && i < size; i++) action.accept((E) elementData[i]);
        if (modCount != expectedModCount) throw new ConcurrentModificationException();
    }
    public void replaceAll(UnaryOperator<E> operator) {
        Objects.requireNonNull(operator);
        for (int i = 0; i < size; i++) elementData[i] = operator.apply((E) elementData[i]);
        modCount++;
    }
    public void sort(Comparator<? super E> c) {
        int expectedModCount = modCount;
        Arrays.sort((E[]) elementData, 0, size, c);
        if (modCount != expectedModCount) throw new ConcurrentModificationException();
        modCount++;
    }
    public Iterator<E> iterator() { return new Itr(); }
    private class Itr implements Iterator<E> {
        int cursor;
        int lastRet = -1;
        int expectedModCount = modCount;
        public boolean hasNext() { return cursor != size; }
        public E next() {
            if (modCount != expectedModCount) throw new ConcurrentModificationException();
            int i = cursor;
            if (i >= size) throw new NoSuchElementException();
            cursor = i + 1;
            return (E) elementData[lastRet = i];
        }
        public void remove() {
            if (lastRet < 0) throw new IllegalStateException();
            if (modCount != expectedModCount) throw new ConcurrentModificationException();
            ArrayList.this.remove(lastRet);
            cursor = lastRet;
            lastRet = -1;
            expectedModCount = modCount;
        }
    }
    public boolean equals(Object o) {
        if (o == this) return true;
        if (!(o instanceof List)) return false;
        List<?> other = (List<?>) o;
        if (other.size() != size) return false;
        Iterator<?> it = other.iterator();
        for (int i = 0; i < size; i++) {
            Object a = elementData[i], b = it.next();
            if (!(a == null ? b == null : a.equals(b))) return false;
        }
        return true;
    }
    public int hashCode() {
        int h = 1;
        for (int i = 0; i < size; i++) { Object e = elementData[i]; h = 31 * h + (e == null ? 0 : e.hashCode()); }
        return h;
    }
}
