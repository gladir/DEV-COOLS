package java.util;
import java.util.function.*;
public class Vector<E> extends AbstractList<E> implements List<E>, RandomAccess, Cloneable, java.io.Serializable {
    private static final long serialVersionUID = -2767605614048989439L;
    protected Object[] elementData;
    protected int elementCount;
    protected int capacityIncrement;
    public Vector(int initialCapacity, int capacityIncrement) {
        super();
        if (initialCapacity < 0) throw new IllegalArgumentException("Illegal Capacity: " + initialCapacity);
        this.elementData = new Object[initialCapacity];
        this.capacityIncrement = capacityIncrement;
    }
    public Vector(int initialCapacity) { this(initialCapacity, 0); }
    public Vector() { this(10); }
    public Vector(Collection<? extends E> c) {
        Object[] a = c.toArray();
        elementCount = a.length;
        if (c.getClass() == ArrayList.class) elementData = a;
        else elementData = Arrays.copyOf(a, elementCount, Object[].class);
    }
    public synchronized void copyInto(Object[] anArray) { System.arraycopy(elementData, 0, anArray, 0, elementCount); }
    public synchronized void trimToSize() {
        modCount++;
        if (elementCount < elementData.length) elementData = Arrays.copyOf(elementData, elementCount);
    }
    public synchronized void ensureCapacity(int minCapacity) {
        if (minCapacity > 0) { modCount++; if (minCapacity > elementData.length) grow(minCapacity); }
    }
    private Object[] grow(int minCapacity) {
        int oldCapacity = elementData.length;
        int newCapacity = oldCapacity + (capacityIncrement > 0 ? capacityIncrement : oldCapacity);
        if (newCapacity < minCapacity) newCapacity = minCapacity;
        return elementData = Arrays.copyOf(elementData, newCapacity);
    }
    private Object[] grow() { return grow(elementCount + 1); }
    public synchronized void setSize(int newSize) {
        modCount++;
        if (newSize > elementData.length) grow(newSize);
        final Object[] es = elementData;
        for (int to = elementCount, i = newSize; i < to; i++) es[i] = null;
        elementCount = newSize;
    }
    public synchronized int capacity() { return elementData.length; }
    public synchronized int size() { return elementCount; }
    public synchronized boolean isEmpty() { return elementCount == 0; }
    public Enumeration<E> elements() {
        return new Enumeration<E>() {
            int count = 0;
            public boolean hasMoreElements() { return count < elementCount; }
            public E nextElement() {
                synchronized (Vector.this) {
                    if (count < elementCount) return elementData(count++);
                }
                throw new NoSuchElementException("Vector Enumeration");
            }
        };
    }
    public boolean contains(Object o) { return indexOf(o, 0) >= 0; }
    public int indexOf(Object o) { return indexOf(o, 0); }
    public synchronized int indexOf(Object o, int index) {
        if (o == null) { for (int i = index; i < elementCount; i++) if (elementData[i] == null) return i; }
        else { for (int i = index; i < elementCount; i++) if (o.equals(elementData[i])) return i; }
        return -1;
    }
    public synchronized int lastIndexOf(Object o) { return lastIndexOf(o, elementCount - 1); }
    public synchronized int lastIndexOf(Object o, int index) {
        if (index >= elementCount) throw new IndexOutOfBoundsException(index + " >= " + elementCount);
        if (o == null) { for (int i = index; i >= 0; i--) if (elementData[i] == null) return i; }
        else { for (int i = index; i >= 0; i--) if (o.equals(elementData[i])) return i; }
        return -1;
    }
    public synchronized E elementAt(int index) {
        if (index >= elementCount) throw new ArrayIndexOutOfBoundsException(index + " >= " + elementCount);
        return elementData(index);
    }
    public synchronized E firstElement() {
        if (elementCount == 0) throw new NoSuchElementException();
        return elementData(0);
    }
    public synchronized E lastElement() {
        if (elementCount == 0) throw new NoSuchElementException();
        return elementData(elementCount - 1);
    }
    public synchronized void setElementAt(E obj, int index) {
        if (index >= elementCount) throw new ArrayIndexOutOfBoundsException(index + " >= " + elementCount);
        elementData[index] = obj;
    }
    public synchronized void removeElementAt(int index) {
        if (index >= elementCount) throw new ArrayIndexOutOfBoundsException(index + " >= " + elementCount);
        else if (index < 0) throw new ArrayIndexOutOfBoundsException(index);
        int j = elementCount - index - 1;
        if (j > 0) System.arraycopy(elementData, index + 1, elementData, index, j);
        modCount++;
        elementCount--;
        elementData[elementCount] = null;
    }
    public synchronized void insertElementAt(E obj, int index) {
        if (index > elementCount) throw new ArrayIndexOutOfBoundsException(index + " > " + elementCount);
        modCount++;
        final int s = elementCount;
        Object[] elementData = this.elementData;
        if (s == elementData.length) elementData = grow();
        System.arraycopy(elementData, index, elementData, index + 1, s - index);
        elementData[index] = obj;
        elementCount = s + 1;
    }
    public synchronized void addElement(E obj) {
        modCount++;
        add(obj, elementData, elementCount);
    }
    public synchronized boolean removeElement(Object obj) {
        modCount++;
        int i = indexOf(obj);
        if (i >= 0) { removeElementAt(i); return true; }
        return false;
    }
    public synchronized void removeAllElements() {
        final Object[] es = elementData;
        for (int to = elementCount, i = elementCount = 0; i < to; i++) es[i] = null;
        modCount++;
    }
    public synchronized Object clone() {
        Vector<E> v = new Vector<>(elementCount);
        System.arraycopy(elementData, 0, v.elementData, 0, elementCount);
        v.elementCount = elementCount;
        return v;
    }
    public synchronized Object[] toArray() { return Arrays.copyOf(elementData, elementCount); }
    public synchronized <T> T[] toArray(T[] a) {
        if (a.length < elementCount) return (T[]) Arrays.copyOf(elementData, elementCount, a.getClass());
        System.arraycopy(elementData, 0, a, 0, elementCount);
        if (a.length > elementCount) a[elementCount] = null;
        return a;
    }
    E elementData(int index) { return (E) elementData[index]; }
    public synchronized E get(int index) {
        if (index >= elementCount) throw new ArrayIndexOutOfBoundsException(index);
        return elementData(index);
    }
    public synchronized E set(int index, E element) {
        if (index >= elementCount) throw new ArrayIndexOutOfBoundsException(index);
        E oldValue = elementData(index);
        elementData[index] = element;
        return oldValue;
    }
    private void add(E e, Object[] elementData, int s) {
        if (s == elementData.length) elementData = grow();
        elementData[s] = e;
        elementCount = s + 1;
    }
    public synchronized boolean add(E e) {
        modCount++;
        add(e, elementData, elementCount);
        return true;
    }
    public boolean remove(Object o) { return removeElement(o); }
    public void add(int index, E element) { insertElementAt(element, index); }
    public synchronized E remove(int index) {
        modCount++;
        if (index >= elementCount) throw new ArrayIndexOutOfBoundsException(index);
        E oldValue = elementData(index);
        int numMoved = elementCount - index - 1;
        if (numMoved > 0) System.arraycopy(elementData, index + 1, elementData, index, numMoved);
        elementData[--elementCount] = null;
        return oldValue;
    }
    public void clear() { removeAllElements(); }
    public synchronized boolean containsAll(Collection<?> c) { return super.containsAll(c); }
    public boolean addAll(Collection<? extends E> c) {
        Object[] a = c.toArray();
        modCount++;
        int numNew = a.length;
        if (numNew == 0) return false;
        synchronized (this) {
            Object[] elementData = this.elementData;
            final int s = elementCount;
            if (numNew > elementData.length - s) elementData = grow(s + numNew);
            System.arraycopy(a, 0, elementData, s, numNew);
            elementCount = s + numNew;
            return true;
        }
    }
    public synchronized boolean addAll(int index, Collection<? extends E> c) {
        if (index < 0 || index > elementCount) throw new ArrayIndexOutOfBoundsException(index);
        Object[] a = c.toArray();
        modCount++;
        int numNew = a.length;
        if (numNew == 0) return false;
        Object[] elementData = this.elementData;
        final int s = elementCount;
        if (numNew > elementData.length - s) elementData = grow(s + numNew);
        int numMoved = s - index;
        if (numMoved > 0) System.arraycopy(elementData, index, elementData, index + numNew, numMoved);
        System.arraycopy(a, 0, elementData, index, numNew);
        elementCount = s + numNew;
        return true;
    }
    protected synchronized void removeRange(int fromIndex, int toIndex) {
        modCount++;
        shiftTailOverGap(elementData, fromIndex, toIndex);
    }
    private void shiftTailOverGap(Object[] es, int lo, int hi) {
        System.arraycopy(es, hi, es, lo, elementCount - hi);
        for (int to = elementCount, i = (elementCount -= hi - lo); i < to; i++) es[i] = null;
    }
    public synchronized boolean equals(Object o) { return super.equals(o); }
    public synchronized int hashCode() { return super.hashCode(); }
    public synchronized String toString() { return super.toString(); }
    public synchronized List<E> subList(int fromIndex, int toIndex) { return Collections.synchronizedList(super.subList(fromIndex, toIndex)); }
    public synchronized void forEach(Consumer<? super E> action) {
        Objects.requireNonNull(action);
        final int expectedModCount = modCount;
        final Object[] es = elementData;
        final int size = elementCount;
        for (int i = 0; modCount == expectedModCount && i < size; i++) action.accept((E) es[i]);
        if (modCount != expectedModCount) throw new ConcurrentModificationException();
    }
    public synchronized boolean removeIf(Predicate<? super E> filter) {
        Objects.requireNonNull(filter);
        boolean any = false;
        int j = 0;
        final Object[] es = elementData;
        final int n = elementCount;
        for (int i = 0; i < n; i++) {
            E e = (E) es[i];
            if (filter.test(e)) any = true; else es[j++] = e;
        }
        for (int i = j; i < n; i++) es[i] = null;
        elementCount = j;
        if (any) modCount++;
        return any;
    }
    public synchronized void replaceAll(UnaryOperator<E> operator) {
        Objects.requireNonNull(operator);
        for (int i = 0; i < elementCount; i++) elementData[i] = operator.apply((E) elementData[i]);
        modCount++;
    }
    public synchronized void sort(Comparator<? super E> c) {
        final int expectedModCount = modCount;
        Arrays.sort((E[]) elementData, 0, elementCount, c);
        if (modCount != expectedModCount) throw new ConcurrentModificationException();
        modCount++;
    }
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        final java.io.ObjectOutputStream.PutField fields = s.putFields();
        final Object[] data;
        synchronized (this) {
            fields.put("capacityIncrement", capacityIncrement);
            fields.put("elementCount", elementCount);
            data = elementData.clone();
        }
        fields.put("elementData", data);
        s.writeFields();
    }
    private void readObject(java.io.ObjectInputStream in) throws java.io.IOException, ClassNotFoundException {
        java.io.ObjectInputStream.GetField gfields = in.readFields();
        int count = gfields.get("elementCount", 0);
        Object[] data = (Object[]) gfields.get("elementData", null);
        if (count < 0 || data == null || count > data.length) throw new java.io.StreamCorruptedException("Inconsistent vector internals");
        elementCount = count;
        elementData = data.clone();
        capacityIncrement = gfields.get("capacityIncrement", 0);
    }
}
