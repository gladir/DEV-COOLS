package javax.swing.event;
public interface TableColumnModelListener extends java.util.EventListener {
    void columnAdded(TableColumnModelEvent e);
    void columnRemoved(TableColumnModelEvent e);
    void columnMoved(TableColumnModelEvent e);
    void columnMarginChanged(ChangeEvent e);
    void columnSelectionChanged(ListSelectionEvent e);
}
