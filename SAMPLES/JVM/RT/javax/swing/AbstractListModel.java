package javax.swing;
import javax.swing.event.*;
import java.util.EventListener;
public abstract class AbstractListModel<E> implements ListModel<E>, java.io.Serializable {
    protected EventListenerList listenerList = new EventListenerList();
    public void addListDataListener(ListDataListener l) { listenerList.add(ListDataListener.class, l); }
    public void removeListDataListener(ListDataListener l) { listenerList.remove(ListDataListener.class, l); }
    public ListDataListener[] getListDataListeners() { return listenerList.getListeners(ListDataListener.class); }
    protected void fireContentsChanged(Object source, int index0, int index1) {
        Object[] listeners = listenerList.getListenerList();
        ListDataEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == ListDataListener.class) {
                if (e == null) e = new ListDataEvent(source, ListDataEvent.CONTENTS_CHANGED, index0, index1);
                ((ListDataListener) listeners[i + 1]).contentsChanged(e);
            }
        }
    }
    protected void fireIntervalAdded(Object source, int index0, int index1) {
        Object[] listeners = listenerList.getListenerList();
        ListDataEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == ListDataListener.class) {
                if (e == null) e = new ListDataEvent(source, ListDataEvent.INTERVAL_ADDED, index0, index1);
                ((ListDataListener) listeners[i + 1]).intervalAdded(e);
            }
        }
    }
    protected void fireIntervalRemoved(Object source, int index0, int index1) {
        Object[] listeners = listenerList.getListenerList();
        ListDataEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == ListDataListener.class) {
                if (e == null) e = new ListDataEvent(source, ListDataEvent.INTERVAL_REMOVED, index0, index1);
                ((ListDataListener) listeners[i + 1]).intervalRemoved(e);
            }
        }
    }
    public <T extends EventListener> T[] getListeners(Class<T> listenerType) { return listenerList.getListeners(listenerType); }
}
