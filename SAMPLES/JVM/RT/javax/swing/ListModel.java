package javax.swing;
import javax.swing.event.ListDataListener;
public interface ListModel<E> {
    int getSize();
    E getElementAt(int index);
    void addListDataListener(ListDataListener l);
    void removeListDataListener(ListDataListener l);
}
