package javax.swing;
import java.util.EventObject;
import javax.swing.event.*;
public abstract class AbstractCellEditor implements CellEditor, java.io.Serializable {
    protected EventListenerList listenerList = new EventListenerList();
    protected transient ChangeEvent changeEvent = null;
    public boolean isCellEditable(EventObject e) { return true; }
    public boolean shouldSelectCell(EventObject anEvent) { return true; }
    public boolean stopCellEditing() { fireEditingStopped(); return true; }
    public void cancelCellEditing() { fireEditingCanceled(); }
    public void addCellEditorListener(CellEditorListener l) { listenerList.add(CellEditorListener.class, l); }
    public void removeCellEditorListener(CellEditorListener l) { listenerList.remove(CellEditorListener.class, l); }
    public CellEditorListener[] getCellEditorListeners() { return listenerList.getListeners(CellEditorListener.class); }
    protected void fireEditingStopped() {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == CellEditorListener.class) {
                if (changeEvent == null) changeEvent = new ChangeEvent(this);
                ((CellEditorListener) listeners[i + 1]).editingStopped(changeEvent);
            }
        }
    }
    protected void fireEditingCanceled() {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == CellEditorListener.class) {
                if (changeEvent == null) changeEvent = new ChangeEvent(this);
                ((CellEditorListener) listeners[i + 1]).editingCanceled(changeEvent);
            }
        }
    }
}
