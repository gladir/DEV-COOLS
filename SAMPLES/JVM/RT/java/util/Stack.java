package java.util;
public class Stack<E> extends Vector<E> {
    private static final long serialVersionUID = 1224463164541339165L;
    public Stack() {}
    public E push(E item) { add(item); return item; }
    public E pop() { E obj = peek(); remove(size() - 1); return obj; }
    public E peek() { int len = size(); if (len == 0) throw new EmptyStackException(); return get(len - 1); }
    public boolean empty() { return size() == 0; }
    public int search(Object o) { int i = lastIndexOf(o); if (i >= 0) return size() - i; return -1; }
}
