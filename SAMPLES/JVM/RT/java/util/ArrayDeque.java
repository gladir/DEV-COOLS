package java.util;
public class ArrayDeque<E> extends AbstractCollection<E> implements Deque<E>, Cloneable, java.io.Serializable {
    transient Object[] elements;
    transient int head;
    transient int tail;
    public ArrayDeque() { elements = new Object[17]; }
    public ArrayDeque(int numElements) { elements = new Object[Math.max(numElements, 1) + 1]; }
    public ArrayDeque(Collection<? extends E> c) { this(c.size()); addAll(c); }
    private void grow() {
        int n = elements.length;
        Object[] a = new Object[n * 2];
        int s = size();
        for (int i = 0; i < s; i++) a[i] = elements[(head + i) % n];
        elements = a; head = 0; tail = s;
    }
    public void addFirst(E e) {
        if (e == null) throw new NullPointerException();
        head = (head - 1 + elements.length) % elements.length;
        elements[head] = e;
        if (head == tail) { tail = (tail + 1) % elements.length; /* recover */ elements[head] = null; head = (head + 1) % elements.length; regrowFirst(e); }
    }
    private void regrowFirst(E e) {
        // le tampon etait plein : on agrandit puis on insere en tete
        int n = elements.length;
        Object[] a = new Object[n * 2];
        int s = 0;
        for (int i = 0; i < n - 1; i++) a[1 + s++] = elements[(head + i) % n];
        a[0] = e;
        elements = a; head = 0; tail = s + 1;
    }
    public void addLast(E e) {
        if (e == null) throw new NullPointerException();
        elements[tail] = e;
        tail = (tail + 1) % elements.length;
        if (tail == head) { int n = elements.length; Object[] a = new Object[n * 2]; for (int i = 0; i < n; i++) a[i] = elements[(head + i) % n]; elements = a; head = 0; tail = n; }
    }
    public boolean offerFirst(E e) { addFirst(e); return true; }
    public boolean offerLast(E e) { addLast(e); return true; }
    public E removeFirst() { E x = pollFirst(); if (x == null) throw new NoSuchElementException(); return x; }
    public E removeLast() { E x = pollLast(); if (x == null) throw new NoSuchElementException(); return x; }
    public E pollFirst() {
        if (head == tail) return null;
        E r = (E) elements[head];
        elements[head] = null;
        head = (head + 1) % elements.length;
        return r;
    }
    public E pollLast() {
        if (head == tail) return null;
        tail = (tail - 1 + elements.length) % elements.length;
        E r = (E) elements[tail];
        elements[tail] = null;
        return r;
    }
    public E getFirst() { E x = peekFirst(); if (x == null) throw new NoSuchElementException(); return x; }
    public E getLast() { E x = peekLast(); if (x == null) throw new NoSuchElementException(); return x; }
    public E peekFirst() { return head == tail ? null : (E) elements[head]; }
    public E peekLast() { return head == tail ? null : (E) elements[(tail - 1 + elements.length) % elements.length]; }
    public boolean removeFirstOccurrence(Object o) {
        int n = elements.length, s = size();
        for (int i = 0; i < s; i++) if (o != null && o.equals(elements[(head + i) % n])) { delete(i); return true; }
        return false;
    }
    public boolean removeLastOccurrence(Object o) {
        int n = elements.length, s = size();
        for (int i = s - 1; i >= 0; i--) if (o != null && o.equals(elements[(head + i) % n])) { delete(i); return true; }
        return false;
    }
    private void delete(int idx) {
        int n = elements.length, s = size();
        for (int i = idx; i < s - 1; i++) elements[(head + i) % n] = elements[(head + i + 1) % n];
        tail = (tail - 1 + n) % n;
        elements[tail] = null;
    }
    public boolean add(E e) { addLast(e); return true; }
    public boolean offer(E e) { return offerLast(e); }
    public E remove() { return removeFirst(); }
    public E poll() { return pollFirst(); }
    public E element() { return getFirst(); }
    public E peek() { return peekFirst(); }
    public void push(E e) { addFirst(e); }
    public E pop() { return removeFirst(); }
    public int size() { return (tail - head + elements.length) % elements.length; }
    public boolean isEmpty() { return head == tail; }
    public Iterator<E> iterator() {
        return new Iterator<E>() {
            int i = 0;
            int last = -1;
            public boolean hasNext() { return i < size(); }
            public E next() { if (i >= size()) throw new NoSuchElementException(); last = i; return (E) elements[(head + i++) % elements.length]; }
            public void remove() { if (last < 0) throw new IllegalStateException(); delete(last); i = last; last = -1; }
        };
    }
    public Iterator<E> descendingIterator() {
        return new Iterator<E>() {
            int i = size() - 1;
            public boolean hasNext() { return i >= 0; }
            public E next() { if (i < 0) throw new NoSuchElementException(); return (E) elements[(head + i--) % elements.length]; }
        };
    }
    public boolean contains(Object o) {
        if (o == null) return false;
        int n = elements.length, s = size();
        for (int i = 0; i < s; i++) if (o.equals(elements[(head + i) % n])) return true;
        return false;
    }
    public boolean remove(Object o) { return removeFirstOccurrence(o); }
    public void clear() { elements = new Object[17]; head = tail = 0; }
    public ArrayDeque<E> clone() { return new ArrayDeque<E>(this); }
}
