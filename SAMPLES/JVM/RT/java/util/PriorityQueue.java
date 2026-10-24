package java.util;
public class PriorityQueue<E> extends AbstractQueue<E> implements java.io.Serializable {
    private static final long serialVersionUID = -7720805057305804111L;
    transient Object[] queue;
    int size;
    private final Comparator<? super E> comparator;
    transient int modCount;
    public PriorityQueue() { this(11, null); }
    public PriorityQueue(int initialCapacity) { this(initialCapacity, null); }
    public PriorityQueue(Comparator<? super E> comparator) { this(11, comparator); }
    public PriorityQueue(int initialCapacity, Comparator<? super E> comparator) {
        if (initialCapacity < 1) throw new IllegalArgumentException();
        this.queue = new Object[initialCapacity];
        this.comparator = comparator;
    }
    public PriorityQueue(Collection<? extends E> c) {
        this(Math.max(11, c.size() + 1), (c instanceof PriorityQueue) ? ((PriorityQueue<? extends E>) c).comparator : (c instanceof SortedSet) ? ((SortedSet<? extends E>) c).comparator() : null);
        for (E e : c) offer(e);
    }
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        s.defaultWriteObject();
        s.writeInt(Math.max(2, size + 1));
        for (int i = 0; i < size; i++) s.writeObject(queue[i]);
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        s.readInt();
        queue = new Object[Math.max(1, size)];
        for (int i = 0; i < size; i++) queue[i] = s.readObject();
        for (int i = (size >>> 1) - 1; i >= 0; i--) siftDown(i, (E) queue[i]);
    }
    public boolean add(E e) { return offer(e); }
    public boolean offer(E e) {
        if (e == null) throw new NullPointerException();
        modCount++;
        int i = size;
        if (i >= queue.length) queue = Arrays.copyOf(queue, queue.length < 64 ? queue.length * 2 + 2 : queue.length + (queue.length >> 1));
        siftUp(i, e);
        size = i + 1;
        return true;
    }
    public E peek() { return (size == 0) ? null : (E) queue[0]; }
    private int indexOf(Object o) {
        if (o != null) { for (int i = 0; i < size; i++) if (o.equals(queue[i])) return i; }
        return -1;
    }
    public boolean remove(Object o) {
        int i = indexOf(o);
        if (i == -1) return false;
        removeAt(i);
        return true;
    }
    public boolean contains(Object o) { return indexOf(o) >= 0; }
    public Object[] toArray() { return Arrays.copyOf(queue, size); }
    public <T> T[] toArray(T[] a) {
        if (a.length < size) return (T[]) Arrays.copyOf(queue, size, a.getClass());
        System.arraycopy(queue, 0, a, 0, size);
        if (a.length > size) a[size] = null;
        return a;
    }
    public Iterator<E> iterator() {
        return new Iterator<E>() {
            int cursor = 0;
            int lastRet = -1;
            int expectedModCount = modCount;
            public boolean hasNext() { return cursor < size; }
            public E next() {
                if (expectedModCount != modCount) throw new ConcurrentModificationException();
                if (cursor < size) return (E) queue[lastRet = cursor++];
                throw new NoSuchElementException();
            }
            public void remove() {
                if (expectedModCount != modCount) throw new ConcurrentModificationException();
                if (lastRet < 0) throw new IllegalStateException();
                removeAt(lastRet);
                cursor = lastRet;
                lastRet = -1;
                expectedModCount = modCount;
            }
        };
    }
    public int size() { return size; }
    public void clear() { modCount++; for (int i = 0; i < size; i++) queue[i] = null; size = 0; }
    public E poll() {
        if (size == 0) return null;
        final E result = (E) queue[0];
        modCount++;
        final int n = --size;
        final E x = (E) queue[n];
        queue[n] = null;
        if (n > 0) siftDown(0, x);
        return result;
    }
    E removeAt(int i) {
        modCount++;
        int s = --size;
        if (s == i) queue[i] = null;
        else {
            E moved = (E) queue[s];
            queue[s] = null;
            siftDown(i, moved);
            if (queue[i] == moved) { siftUp(i, moved); if (queue[i] != moved) return moved; }
        }
        return null;
    }
    private void siftUp(int k, E x) {
        if (comparator != null) {
            while (k > 0) {
                int parent = (k - 1) >>> 1;
                Object e = queue[parent];
                if (comparator.compare(x, (E) e) >= 0) break;
                queue[k] = e;
                k = parent;
            }
        } else {
            Comparable<? super E> key = (Comparable<? super E>) x;
            while (k > 0) {
                int parent = (k - 1) >>> 1;
                Object e = queue[parent];
                if (key.compareTo((E) e) >= 0) break;
                queue[k] = e;
                k = parent;
            }
        }
        queue[k] = x;
    }
    private void siftDown(int k, E x) {
        int half = size >>> 1;
        if (comparator != null) {
            while (k < half) {
                int child = (k << 1) + 1;
                Object c = queue[child];
                int right = child + 1;
                if (right < size && comparator.compare((E) c, (E) queue[right]) > 0) c = queue[child = right];
                if (comparator.compare(x, (E) c) <= 0) break;
                queue[k] = c;
                k = child;
            }
        } else {
            Comparable<? super E> key = (Comparable<? super E>) x;
            while (k < half) {
                int child = (k << 1) + 1;
                Object c = queue[child];
                int right = child + 1;
                if (right < size && ((Comparable<? super E>) c).compareTo((E) queue[right]) > 0) c = queue[child = right];
                if (key.compareTo((E) c) <= 0) break;
                queue[k] = c;
                k = child;
            }
        }
        queue[k] = x;
    }
    public Comparator<? super E> comparator() { return comparator; }
}
