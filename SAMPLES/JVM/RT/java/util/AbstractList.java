package java.util;
public abstract class AbstractList<E> extends AbstractCollection<E> implements List<E> {
    protected transient int modCount = 0;
    protected AbstractList() {}
    public boolean add(E e) { add(size(), e); return true; }
    public abstract E get(int index);
    public E set(int index, E element) { throw new UnsupportedOperationException(); }
    public void add(int index, E element) { throw new UnsupportedOperationException(); }
    public E remove(int index) { throw new UnsupportedOperationException(); }
    public int indexOf(Object o) {
        ListIterator<E> it = listIterator();
        if (o == null) { while (it.hasNext()) if (it.next() == null) return it.previousIndex(); }
        else { while (it.hasNext()) if (o.equals(it.next())) return it.previousIndex(); }
        return -1;
    }
    public int lastIndexOf(Object o) {
        ListIterator<E> it = listIterator(size());
        if (o == null) { while (it.hasPrevious()) if (it.previous() == null) return it.nextIndex(); }
        else { while (it.hasPrevious()) if (o.equals(it.previous())) return it.nextIndex(); }
        return -1;
    }
    public void clear() { removeRange(0, size()); }
    public boolean addAll(int index, Collection<? extends E> c) {
        boolean modified = false;
        for (E e : c) { add(index++, e); modified = true; }
        return modified;
    }
    public Iterator<E> iterator() { return new Itr(); }
    public ListIterator<E> listIterator() { return listIterator(0); }
    public ListIterator<E> listIterator(final int index) {
        if (index < 0 || index > size()) throw new IndexOutOfBoundsException("Index: " + index);
        return new ListItr(index);
    }
    private class Itr implements Iterator<E> {
        int cursor = 0;
        int lastRet = -1;
        int expectedModCount = modCount;
        public boolean hasNext() { return cursor != size(); }
        public E next() {
            checkForComodification();
            try {
                int i = cursor;
                E next = get(i);
                lastRet = i;
                cursor = i + 1;
                return next;
            } catch (IndexOutOfBoundsException e) {
                checkForComodification();
                throw new NoSuchElementException();
            }
        }
        public void remove() {
            if (lastRet < 0) throw new IllegalStateException();
            checkForComodification();
            AbstractList.this.remove(lastRet);
            if (lastRet < cursor) cursor--;
            lastRet = -1;
            expectedModCount = modCount;
        }
        final void checkForComodification() { if (modCount != expectedModCount) throw new ConcurrentModificationException(); }
    }
    private class ListItr extends Itr implements ListIterator<E> {
        ListItr(int index) { cursor = index; }
        public boolean hasPrevious() { return cursor != 0; }
        public E previous() {
            checkForComodification();
            try {
                int i = cursor - 1;
                E previous = get(i);
                lastRet = cursor = i;
                return previous;
            } catch (IndexOutOfBoundsException e) {
                checkForComodification();
                throw new NoSuchElementException();
            }
        }
        public int nextIndex() { return cursor; }
        public int previousIndex() { return cursor - 1; }
        public void set(E e) {
            if (lastRet < 0) throw new IllegalStateException();
            checkForComodification();
            AbstractList.this.set(lastRet, e);
            expectedModCount = modCount;
        }
        public void add(E e) {
            checkForComodification();
            int i = cursor;
            AbstractList.this.add(i, e);
            lastRet = -1;
            cursor = i + 1;
            expectedModCount = modCount;
        }
    }
    public List<E> subList(int fromIndex, int toIndex) {
        if (fromIndex < 0) throw new IndexOutOfBoundsException("fromIndex = " + fromIndex);
        if (toIndex > size()) throw new IndexOutOfBoundsException("toIndex = " + toIndex);
        if (fromIndex > toIndex) throw new IllegalArgumentException("fromIndex(" + fromIndex + ") > toIndex(" + toIndex + ")");
        return new SubList<>(this, fromIndex, toIndex);
    }
    public boolean equals(Object o) {
        if (o == this) return true;
        if (!(o instanceof List)) return false;
        Iterator<E> e1 = iterator();
        Iterator<?> e2 = ((List<?>) o).iterator();
        while (e1.hasNext() && e2.hasNext()) {
            E o1 = e1.next();
            Object o2 = e2.next();
            if (!(o1 == null ? o2 == null : o1.equals(o2))) return false;
        }
        return !(e1.hasNext() || e2.hasNext());
    }
    public int hashCode() {
        int hashCode = 1;
        for (E e : this) hashCode = 31 * hashCode + (e == null ? 0 : e.hashCode());
        return hashCode;
    }
    protected void removeRange(int fromIndex, int toIndex) {
        ListIterator<E> it = listIterator(fromIndex);
        for (int i = 0, n = toIndex - fromIndex; i < n; i++) { it.next(); it.remove(); }
    }
    private static class SubList<E> extends AbstractList<E> {
        private final AbstractList<E> root;
        private final int offset;
        private int size;
        SubList(AbstractList<E> root, int from, int to) { this.root = root; this.offset = from; this.size = to - from; this.modCount = root.modCount; }
        public E set(int index, E element) { Objects.checkIndex(index, size); return root.set(offset + index, element); }
        public E get(int index) { Objects.checkIndex(index, size); checkMod(); return root.get(offset + index); }
        public int size() { checkMod(); return size; }
        public void add(int index, E element) {
            if (index < 0 || index > size) throw new IndexOutOfBoundsException("Index: " + index + ", Size: " + size);
            checkMod();
            root.add(offset + index, element);
            this.modCount = root.modCount;
            size++;
        }
        public E remove(int index) {
            Objects.checkIndex(index, size);
            checkMod();
            E result = root.remove(offset + index);
            this.modCount = root.modCount;
            size--;
            return result;
        }
        protected void removeRange(int fromIndex, int toIndex) {
            checkMod();
            root.removeRange(offset + fromIndex, offset + toIndex);
            this.modCount = root.modCount;
            size -= toIndex - fromIndex;
        }
        private void checkMod() { if (root.modCount != this.modCount) throw new ConcurrentModificationException(); }
    }
}
