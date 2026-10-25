package javax.swing.event;
public interface ListDataListener extends java.util.EventListener {
    void intervalAdded(ListDataEvent e);
    void intervalRemoved(ListDataEvent e);
    void contentsChanged(ListDataEvent e);
}
