package javax.swing;
import java.util.EventObject;
import javax.swing.event.*;
public interface CellEditor {
    Object getCellEditorValue();
    boolean isCellEditable(EventObject anEvent);
    boolean shouldSelectCell(EventObject anEvent);
    boolean stopCellEditing();
    void cancelCellEditing();
    void addCellEditorListener(CellEditorListener l);
    void removeCellEditorListener(CellEditorListener l);
}
