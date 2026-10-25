package javax.swing.table;
import java.beans.*;
import java.util.*;
import javax.swing.*;
import javax.swing.event.*;
public class DefaultTableColumnModel implements TableColumnModel, PropertyChangeListener, ListSelectionListener, java.io.Serializable {
    protected Vector<TableColumn> tableColumns;
    protected ListSelectionModel selectionModel;
    protected int columnMargin;
    protected EventListenerList listenerList = new EventListenerList();
    protected transient ChangeEvent changeEvent = null;
    protected boolean columnSelectionAllowed;
    protected int totalColumnWidth;
    public DefaultTableColumnModel() {
        super();
        tableColumns = new Vector<TableColumn>();
        setSelectionModel(createSelectionModel());
        setColumnMargin(1);
        invalidateWidthCache();
        columnSelectionAllowed = false;
    }
    public void addColumn(TableColumn aColumn) {
        if (aColumn == null) throw new IllegalArgumentException("Object is null");
        tableColumns.addElement(aColumn);
        aColumn.addPropertyChangeListener(this);
        invalidateWidthCache();
        fireColumnAdded(new TableColumnModelEvent(this, 0, getColumnCount() - 1));
    }
    public void removeColumn(TableColumn column) {
        int columnIndex = tableColumns.indexOf(column);
        if (columnIndex != -1) {
            if (selectionModel != null) selectionModel.removeIndexInterval(columnIndex, columnIndex);
            column.removePropertyChangeListener(this);
            tableColumns.removeElementAt(columnIndex);
            invalidateWidthCache();
            fireColumnRemoved(new TableColumnModelEvent(this, columnIndex, 0));
        }
    }
    public void moveColumn(int columnIndex, int newIndex) {
        if ((columnIndex < 0) || (columnIndex >= getColumnCount()) || (newIndex < 0) || (newIndex >= getColumnCount()))
            throw new IllegalArgumentException("moveColumn() - Index out of range");
        TableColumnModelEvent evt = new TableColumnModelEvent(this, columnIndex, newIndex);
        if (columnIndex == newIndex) { fireColumnMoved(evt); return; }
        TableColumn aColumn = tableColumns.elementAt(columnIndex);
        tableColumns.removeElementAt(columnIndex);
        boolean selected = selectionModel.isSelectedIndex(columnIndex);
        selectionModel.removeIndexInterval(columnIndex, columnIndex);
        tableColumns.insertElementAt(aColumn, newIndex);
        selectionModel.insertIndexInterval(newIndex, 1, true);
        if (selected) selectionModel.addSelectionInterval(newIndex, newIndex);
        else selectionModel.removeSelectionInterval(newIndex, newIndex);
        fireColumnMoved(evt);
    }
    public void setColumnMargin(int newMargin) {
        if (newMargin != columnMargin) {
            columnMargin = newMargin;
            fireColumnMarginChanged();
        }
    }
    public int getColumnCount() { return tableColumns.size(); }
    public Enumeration<TableColumn> getColumns() { return tableColumns.elements(); }
    public int getColumnIndex(Object identifier) {
        if (identifier == null) throw new IllegalArgumentException("Identifier is null");
        Enumeration<TableColumn> enumeration = getColumns();
        TableColumn aColumn;
        int index = 0;
        while (enumeration.hasMoreElements()) {
            aColumn = enumeration.nextElement();
            if (identifier.equals(aColumn.getIdentifier())) return index;
            index++;
        }
        throw new IllegalArgumentException("Identifier not found");
    }
    public TableColumn getColumn(int columnIndex) { return tableColumns.elementAt(columnIndex); }
    public int getColumnMargin() { return columnMargin; }
    public int getColumnIndexAtX(int x) {
        if (x < 0) return -1;
        int cc = getColumnCount();
        for (int column = 0; column < cc; column++) {
            x = x - getColumn(column).getWidth();
            if (x < 0) return column;
        }
        return -1;
    }
    public int getTotalColumnWidth() {
        if (totalColumnWidth == -1) recalcWidthCache();
        return totalColumnWidth;
    }
    public void setSelectionModel(ListSelectionModel newModel) {
        if (newModel == null) throw new IllegalArgumentException("Cannot set a null SelectionModel");
        ListSelectionModel oldModel = selectionModel;
        if (newModel != oldModel) {
            if (oldModel != null) oldModel.removeListSelectionListener(this);
            selectionModel = newModel;
            newModel.addListSelectionListener(this);
        }
    }
    public ListSelectionModel getSelectionModel() { return selectionModel; }
    public void setColumnSelectionAllowed(boolean flag) { columnSelectionAllowed = flag; }
    public boolean getColumnSelectionAllowed() { return columnSelectionAllowed; }
    public int[] getSelectedColumns() {
        if (selectionModel != null) {
            int iMin = selectionModel.getMinSelectionIndex();
            int iMax = selectionModel.getMaxSelectionIndex();
            if ((iMin == -1) || (iMax == -1)) return new int[0];
            int[] rvTmp = new int[1 + (iMax - iMin)];
            int n = 0;
            for (int i = iMin; i <= iMax; i++) if (selectionModel.isSelectedIndex(i)) rvTmp[n++] = i;
            int[] rv = new int[n];
            System.arraycopy(rvTmp, 0, rv, 0, n);
            return rv;
        }
        return new int[0];
    }
    public int getSelectedColumnCount() {
        if (selectionModel != null) {
            int iMin = selectionModel.getMinSelectionIndex();
            int iMax = selectionModel.getMaxSelectionIndex();
            int count = 0;
            for (int i = iMin; i <= iMax; i++) if (selectionModel.isSelectedIndex(i)) count++;
            return count;
        }
        return 0;
    }
    public void addColumnModelListener(TableColumnModelListener x) { listenerList.add(TableColumnModelListener.class, x); }
    public void removeColumnModelListener(TableColumnModelListener x) { listenerList.remove(TableColumnModelListener.class, x); }
    public TableColumnModelListener[] getColumnModelListeners() { return listenerList.getListeners(TableColumnModelListener.class); }
    protected void fireColumnAdded(TableColumnModelEvent e) {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) if (listeners[i] == TableColumnModelListener.class) ((TableColumnModelListener) listeners[i + 1]).columnAdded(e);
    }
    protected void fireColumnRemoved(TableColumnModelEvent e) {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) if (listeners[i] == TableColumnModelListener.class) ((TableColumnModelListener) listeners[i + 1]).columnRemoved(e);
    }
    protected void fireColumnMoved(TableColumnModelEvent e) {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) if (listeners[i] == TableColumnModelListener.class) ((TableColumnModelListener) listeners[i + 1]).columnMoved(e);
    }
    protected void fireColumnSelectionChanged(ListSelectionEvent e) {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) if (listeners[i] == TableColumnModelListener.class) ((TableColumnModelListener) listeners[i + 1]).columnSelectionChanged(e);
    }
    protected void fireColumnMarginChanged() {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TableColumnModelListener.class) {
                if (changeEvent == null) changeEvent = new ChangeEvent(this);
                ((TableColumnModelListener) listeners[i + 1]).columnMarginChanged(changeEvent);
            }
        }
    }
    public <T extends EventListener> T[] getListeners(Class<T> listenerType) { return listenerList.getListeners(listenerType); }
    public void propertyChange(PropertyChangeEvent evt) {
        String name = evt.getPropertyName();
        if ("width".equals(name) || "preferredWidth".equals(name)) {
            invalidateWidthCache();
            fireColumnMarginChanged();
        }
    }
    public void valueChanged(ListSelectionEvent e) { fireColumnSelectionChanged(e); }
    protected ListSelectionModel createSelectionModel() { return new DefaultListSelectionModel(); }
    protected void recalcWidthCache() {
        if (totalColumnWidth == -1) {
            totalColumnWidth = 0;
            for (int i = 0; i < getColumnCount(); i++) totalColumnWidth += getColumn(i).getWidth();
        }
    }
    private void invalidateWidthCache() { totalColumnWidth = -1; }
}
