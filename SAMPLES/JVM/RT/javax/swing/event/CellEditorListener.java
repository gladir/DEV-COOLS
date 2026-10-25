package javax.swing.event;
public interface CellEditorListener extends java.util.EventListener {
    void editingStopped(ChangeEvent e);
    void editingCanceled(ChangeEvent e);
}
