package javax.swing;
import java.util.*;
public class DefaultListModel<E> {
    private final ArrayList<E> l = new ArrayList<>();
    public void addElement(E e) { l.add(e); }
    public void add(int i, E e) { l.add(i, e); }
    public E getElementAt(int i) { return l.get(i); }
    public E get(int i) { return l.get(i); }
    public int getSize() { return l.size(); }
    public int size() { return l.size(); }
    public E remove(int i) { return l.remove(i); }
    public boolean removeElement(Object o) { return l.remove(o); }
    public void removeAllElements() { l.clear(); }
    public void clear() { l.clear(); }
    public boolean contains(Object o) { return l.contains(o); }
    public boolean isEmpty() { return l.isEmpty(); }
}
