package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.text.NumberFormat;
import java.util.*;
import java.util.List;
import javax.swing.border.*;
import javax.swing.event.*;
import javax.swing.table.*;
public class JTable extends JComponent implements TableModelListener, Scrollable, TableColumnModelListener, ListSelectionListener, CellEditorListener, RowSorterListener {
    public static final int AUTO_RESIZE_OFF = 0, AUTO_RESIZE_NEXT_COLUMN = 1, AUTO_RESIZE_SUBSEQUENT_COLUMNS = 2, AUTO_RESIZE_LAST_COLUMN = 3, AUTO_RESIZE_ALL_COLUMNS = 4;
    protected TableModel dataModel;
    protected TableColumnModel columnModel;
    protected ListSelectionModel selectionModel;
    protected JTableHeader tableHeader;
    protected int rowHeight;
    protected int rowMargin;
    protected Color gridColor;
    protected boolean showHorizontalLines;
    protected boolean showVerticalLines;
    protected int autoResizeMode;
    protected boolean autoCreateColumnsFromModel;
    protected Dimension preferredViewportSize;
    protected boolean rowSelectionAllowed;
    protected boolean cellSelectionEnabled;
    protected transient Component editorComp;
    protected transient TableCellEditor cellEditor;
    protected transient int editingColumn;
    protected transient int editingRow;
    protected transient HashMap<Class<?>, TableCellRenderer> defaultRenderersByColumnClass = new HashMap<>();
    protected transient HashMap<Class<?>, TableCellEditor> defaultEditorsByColumnClass = new HashMap<>();
    protected Color selectionForeground;
    protected Color selectionBackground;
    private boolean fillsViewportHeight;
    private boolean autoCreateRowSorter;
    private RowSorter<? extends TableModel> sorter;
    private boolean ignoreSort;
    private HashMap<Integer, Integer> rowHeightMap;
    private KeyListener editorKeys;
    private int pressedRow = -1, pressedCol = -1;
    private int dragAnchorRow = -1;
    private boolean surrenders;
    public JTable() { this(null, null, null); }
    public JTable(TableModel dm) { this(dm, null, null); }
    public JTable(TableModel dm, TableColumnModel cm) { this(dm, cm, null); }
    public JTable(TableModel dm, TableColumnModel cm, ListSelectionModel sm) {
        super();
        if (cm == null) { cm = createDefaultColumnModel(); autoCreateColumnsFromModel = true; }
        setColumnModel(cm);
        if (sm == null) sm = createDefaultSelectionModel();
        setSelectionModel(sm);
        if (dm == null) dm = createDefaultDataModel();
        setModel(dm);
        initializeLocalVars();
    }
    public JTable(int numRows, int numColumns) { this(new DefaultTableModel(numRows, numColumns)); }
    public JTable(Vector<? extends Vector> rowData, Vector<?> columnNames) { this(new DefaultTableModel(rowData, columnNames)); }
    public JTable(final Object[][] rowData, final Object[] columnNames) {
        this(new AbstractTableModel() {
            public String getColumnName(int column) { return columnNames[column].toString(); }
            public int getRowCount() { return rowData.length; }
            public int getColumnCount() { return columnNames.length; }
            public Object getValueAt(int row, int col) { return rowData[row][col]; }
            public boolean isCellEditable(int row, int column) { return true; }
            public void setValueAt(Object value, int row, int col) { rowData[row][col] = value; fireTableCellUpdated(row, col); }
        });
    }
    protected void initializeLocalVars() {
        opaque = true;
        background = Color.WHITE;
        foreground = new Color(51, 51, 51);
        setTableHeader(createDefaultTableHeader());
        setShowGrid(true);
        setAutoResizeMode(AUTO_RESIZE_SUBSEQUENT_COLUMNS);
        rowHeight = 16;
        rowMargin = 1;
        gridColor = new Color(122, 138, 153);
        selectionForeground = new Color(51, 51, 51);
        selectionBackground = new Color(184, 207, 229);
        rowSelectionAllowed = true;
        preferredViewportSize = new Dimension(450, 400);
        editingRow = editingColumn = -1;
        createDefaultRenderers();
        createDefaultEditors();
    }
    protected TableModel createDefaultDataModel() { return new DefaultTableModel(); }
    protected TableColumnModel createDefaultColumnModel() { return new DefaultTableColumnModel(); }
    protected ListSelectionModel createDefaultSelectionModel() { return new DefaultListSelectionModel(); }
    protected JTableHeader createDefaultTableHeader() { return new JTableHeader(columnModel); }
    protected JScrollPane createScrollPaneForTable(JTable aTable) { return new JScrollPane(aTable); }
    public static JScrollPane createScrollPaneForTable(JTable aTable, boolean unused) { return new JScrollPane(aTable); }
    void configureEnclosingScrollPane(JScrollPane sp) {
        if (tableHeader != null && sp.getViewport() != null && sp.getViewport().getView() == this) sp.setColumnHeaderView(tableHeader);
    }
    void unconfigureEnclosingScrollPane(JScrollPane sp) {
        if (sp.getColumnHeader() != null && sp.getColumnHeader().getView() == tableHeader) sp.setColumnHeaderView(null);
    }
    // ---- proprietes ----
    public void setTableHeader(JTableHeader h) {
        if (tableHeader != h) {
            JTableHeader old = tableHeader;
            if (old != null) old.setTable(null);
            tableHeader = h;
            if (h != null) h.setTable(this);
            firePropertyChange("tableHeader", old, h);
        }
    }
    public JTableHeader getTableHeader() { return tableHeader; }
    public void setRowHeight(int rowHeight) {
        if (rowHeight <= 0) throw new IllegalArgumentException("New row height less than 1");
        int old = this.rowHeight;
        this.rowHeight = rowHeight;
        rowHeightMap = null;
        firePropertyChange("rowHeight", old, rowHeight);
        resizeAndRepaint();
    }
    public int getRowHeight() { return rowHeight; }
    public void setRowHeight(int row, int rowHeight) {
        if (rowHeight <= 0) throw new IllegalArgumentException("New row height less than 1");
        if (rowHeightMap == null) rowHeightMap = new HashMap<>();
        rowHeightMap.put(row, rowHeight);
        resizeAndRepaint();
    }
    public int getRowHeight(int row) { if (rowHeightMap != null) { Integer h = rowHeightMap.get(row); if (h != null) return h; } return rowHeight; }
    int rowY(int row) {
        if (rowHeightMap == null) return row * rowHeight;
        int y = 0;
        for (int i = 0; i < row; i++) y += getRowHeight(i);
        return y;
    }
    public void setRowMargin(int m) { int old = rowMargin; rowMargin = m; firePropertyChange("rowMargin", old, m); repaint(); }
    public int getRowMargin() { return rowMargin; }
    public void setIntercellSpacing(Dimension d) { setRowMargin(d.height); getColumnModel().setColumnMargin(d.width); repaint(); }
    public Dimension getIntercellSpacing() { return new Dimension(getColumnModel().getColumnMargin(), rowMargin); }
    public void setGridColor(Color c) { if (c == null) throw new IllegalArgumentException("New color is null"); Color old = gridColor; gridColor = c; firePropertyChange("gridColor", old, c); repaint(); }
    public Color getGridColor() { return gridColor; }
    public void setShowGrid(boolean b) { setShowHorizontalLines(b); setShowVerticalLines(b); repaint(); }
    public void setShowHorizontalLines(boolean b) { boolean old = showHorizontalLines; showHorizontalLines = b; firePropertyChange("showHorizontalLines", old, b); repaint(); }
    public void setShowVerticalLines(boolean b) { boolean old = showVerticalLines; showVerticalLines = b; firePropertyChange("showVerticalLines", old, b); repaint(); }
    public boolean getShowHorizontalLines() { return showHorizontalLines; }
    public boolean getShowVerticalLines() { return showVerticalLines; }
    public void setAutoResizeMode(int mode) {
        if ((mode == AUTO_RESIZE_OFF) || (mode == AUTO_RESIZE_NEXT_COLUMN) || (mode == AUTO_RESIZE_SUBSEQUENT_COLUMNS) || (mode == AUTO_RESIZE_LAST_COLUMN) || (mode == AUTO_RESIZE_ALL_COLUMNS)) {
            int old = autoResizeMode;
            autoResizeMode = mode;
            resizeAndRepaint();
            if (tableHeader != null) tableHeader.resizeAndRepaint();
            firePropertyChange("autoResizeMode", old, autoResizeMode);
        }
    }
    public int getAutoResizeMode() { return autoResizeMode; }
    public void setAutoCreateColumnsFromModel(boolean b) {
        if (autoCreateColumnsFromModel != b) {
            boolean old = autoCreateColumnsFromModel;
            autoCreateColumnsFromModel = b;
            if (b) createDefaultColumnsFromModel();
            firePropertyChange("autoCreateColumnsFromModel", old, b);
        }
    }
    public boolean getAutoCreateColumnsFromModel() { return autoCreateColumnsFromModel; }
    public void setPreferredScrollableViewportSize(Dimension size) { preferredViewportSize = size; }
    public Dimension getPreferredScrollableViewportSize() { return preferredViewportSize; }
    public void setFillsViewportHeight(boolean b) { boolean old = fillsViewportHeight; fillsViewportHeight = b; resizeAndRepaint(); firePropertyChange("fillsViewportHeight", old, b); }
    public boolean getFillsViewportHeight() { return fillsViewportHeight; }
    public void setSurrendersFocusOnKeystroke(boolean b) { surrenders = b; }
    public boolean getSurrendersFocusOnKeystroke() { return surrenders; }
    public void setSelectionForeground(Color c) { Color old = selectionForeground; selectionForeground = c; firePropertyChange("selectionForeground", old, c); repaint(); }
    public Color getSelectionForeground() { return selectionForeground; }
    public void setSelectionBackground(Color c) { Color old = selectionBackground; selectionBackground = c; firePropertyChange("selectionBackground", old, c); repaint(); }
    public Color getSelectionBackground() { return selectionBackground; }
    public void setDragEnabled(boolean b) { }
    public boolean getDragEnabled() { return false; }
    public void setUpdateSelectionOnSort(boolean b) { }
    public boolean getUpdateSelectionOnSort() { return true; }
    // ---- modele ----
    public void setModel(TableModel newModel) {
        if (newModel == null) throw new IllegalArgumentException("Cannot set a null TableModel");
        if (dataModel != newModel) {
            TableModel old = dataModel;
            if (old != null) old.removeTableModelListener(this);
            dataModel = newModel;
            newModel.addTableModelListener(this);
            tableChanged(new TableModelEvent(newModel, TableModelEvent.HEADER_ROW));
            firePropertyChange("model", old, newModel);
            if (getAutoCreateRowSorter()) setRowSorter(new TableRowSorter<TableModel>(newModel));
        }
    }
    public TableModel getModel() { return dataModel; }
    public void setColumnModel(TableColumnModel newModel) {
        if (newModel == null) throw new IllegalArgumentException("Cannot set a null ColumnModel");
        TableColumnModel old = columnModel;
        if (newModel != old) {
            if (old != null) old.removeColumnModelListener(this);
            columnModel = newModel;
            newModel.addColumnModelListener(this);
            if (tableHeader != null) tableHeader.setColumnModel(newModel);
            firePropertyChange("columnModel", old, newModel);
            resizeAndRepaint();
        }
    }
    public TableColumnModel getColumnModel() { return columnModel; }
    public void setSelectionModel(ListSelectionModel newModel) {
        if (newModel == null) throw new IllegalArgumentException("Cannot set a null SelectionModel");
        ListSelectionModel old = selectionModel;
        if (newModel != old) {
            if (old != null) old.removeListSelectionListener(this);
            selectionModel = newModel;
            newModel.addListSelectionListener(this);
            firePropertyChange("selectionModel", old, newModel);
            repaint();
        }
    }
    public ListSelectionModel getSelectionModel() { return selectionModel; }
    public void setRowSorter(RowSorter<? extends TableModel> s) {
        RowSorter<? extends TableModel> old = this.sorter;
        if (old != null) old.removeRowSorterListener(this);
        this.sorter = s;
        if (s != null) s.addRowSorterListener(this);
        clearSelection();
        firePropertyChange("sorter", old, s);
        resizeAndRepaint();
        if (tableHeader != null) tableHeader.repaint();
    }
    public RowSorter<? extends TableModel> getRowSorter() { return sorter; }
    public void setAutoCreateRowSorter(boolean b) {
        boolean old = autoCreateRowSorter;
        autoCreateRowSorter = b;
        if (b) setRowSorter(new TableRowSorter<TableModel>(getModel()));
        firePropertyChange("autoCreateRowSorter", old, b);
    }
    public boolean getAutoCreateRowSorter() { return autoCreateRowSorter; }
    public int convertRowIndexToModel(int viewRowIndex) { return sorter != null ? sorter.convertRowIndexToModel(viewRowIndex) : viewRowIndex; }
    public int convertRowIndexToView(int modelRowIndex) { return sorter != null ? sorter.convertRowIndexToView(modelRowIndex) : modelRowIndex; }
    public int convertColumnIndexToModel(int viewColumnIndex) {
        if (viewColumnIndex < 0) return viewColumnIndex;
        return getColumnModel().getColumn(viewColumnIndex).getModelIndex();
    }
    public int convertColumnIndexToView(int modelColumnIndex) {
        if (modelColumnIndex < 0) return modelColumnIndex;
        TableColumnModel cm = getColumnModel();
        for (int column = 0; column < cm.getColumnCount(); column++) if (cm.getColumn(column).getModelIndex() == modelColumnIndex) return column;
        return -1;
    }
    public int getRowCount() { return sorter != null ? sorter.getViewRowCount() : getModel().getRowCount(); }
    public int getColumnCount() { return getColumnModel().getColumnCount(); }
    public String getColumnName(int column) { return getModel().getColumnName(convertColumnIndexToModel(column)); }
    public int getColumnIndex(Object identifier) { return getColumnModel().getColumnIndex(identifier); }
    public Class<?> getColumnClass(int column) { return getModel().getColumnClass(convertColumnIndexToModel(column)); }
    public Object getValueAt(int row, int column) { return getModel().getValueAt(convertRowIndexToModel(row), convertColumnIndexToModel(column)); }
    public void setValueAt(Object aValue, int row, int column) { getModel().setValueAt(aValue, convertRowIndexToModel(row), convertColumnIndexToModel(column)); }
    public boolean isCellEditable(int row, int column) { return getModel().isCellEditable(convertRowIndexToModel(row), convertColumnIndexToModel(column)); }
    public TableColumn getColumn(Object identifier) {
        TableColumnModel cm = getColumnModel();
        int columnIndex = cm.getColumnIndex(identifier);
        return cm.getColumn(columnIndex);
    }
    public void addColumn(TableColumn aColumn) {
        if (aColumn.getHeaderValue() == null) {
            int modelColumn = aColumn.getModelIndex();
            String columnName = getModel().getColumnName(modelColumn);
            aColumn.setHeaderValue(columnName);
        }
        getColumnModel().addColumn(aColumn);
    }
    public void removeColumn(TableColumn aColumn) { getColumnModel().removeColumn(aColumn); }
    public void moveColumn(int column, int targetColumn) { getColumnModel().moveColumn(column, targetColumn); }
    public void createDefaultColumnsFromModel() {
        TableModel m = getModel();
        if (m != null) {
            TableColumnModel cm = getColumnModel();
            while (cm.getColumnCount() > 0) cm.removeColumn(cm.getColumn(0));
            for (int i = 0; i < m.getColumnCount(); i++) {
                TableColumn newColumn = new TableColumn(i);
                addColumn(newColumn);
            }
        }
    }
    // ---- selection ----
    public void setSelectionMode(int selectionMode) {
        clearSelection();
        getSelectionModel().setSelectionMode(selectionMode);
        getColumnModel().getSelectionModel().setSelectionMode(selectionMode);
    }
    public void setRowSelectionAllowed(boolean b) { boolean old = rowSelectionAllowed; rowSelectionAllowed = b; firePropertyChange("rowSelectionAllowed", old, b); repaint(); }
    public boolean getRowSelectionAllowed() { return rowSelectionAllowed; }
    public void setColumnSelectionAllowed(boolean b) { boolean old = columnModel.getColumnSelectionAllowed(); columnModel.setColumnSelectionAllowed(b); firePropertyChange("columnSelectionAllowed", old, b); repaint(); }
    public boolean getColumnSelectionAllowed() { return columnModel.getColumnSelectionAllowed(); }
    public void setCellSelectionEnabled(boolean b) { setRowSelectionAllowed(b); setColumnSelectionAllowed(b); boolean old = cellSelectionEnabled; cellSelectionEnabled = b; firePropertyChange("cellSelectionEnabled", old, b); }
    public boolean getCellSelectionEnabled() { return getRowSelectionAllowed() && getColumnSelectionAllowed(); }
    public void selectAll() {
        if (isEditing()) removeEditor();
        if (getRowCount() <= 0 || getColumnCount() <= 0) return;
        ListSelectionModel rsm = getSelectionModel();
        ListSelectionModel csm = getColumnModel().getSelectionModel();
        rsm.setValueIsAdjusting(true);
        csm.setValueIsAdjusting(true);
        setRowSelectionInterval(0, getRowCount() - 1);
        setColumnSelectionInterval(0, getColumnCount() - 1);
        rsm.setValueIsAdjusting(false);
        csm.setValueIsAdjusting(false);
    }
    public void clearSelection() { selectionModel.clearSelection(); columnModel.getSelectionModel().clearSelection(); }
    private void checkRow(int i) { if (i < 0 || i >= getRowCount()) throw new IllegalArgumentException("Row index out of range"); }
    private void checkCol(int i) { if (i < 0 || i >= getColumnCount()) throw new IllegalArgumentException("Column index out of range"); }
    public void setRowSelectionInterval(int a, int b) { checkRow(a); checkRow(b); selectionModel.setSelectionInterval(a, b); }
    public void addRowSelectionInterval(int a, int b) { checkRow(a); checkRow(b); selectionModel.addSelectionInterval(a, b); }
    public void removeRowSelectionInterval(int a, int b) { checkRow(a); checkRow(b); selectionModel.removeSelectionInterval(a, b); }
    public void setColumnSelectionInterval(int a, int b) { checkCol(a); checkCol(b); columnModel.getSelectionModel().setSelectionInterval(a, b); }
    public void addColumnSelectionInterval(int a, int b) { checkCol(a); checkCol(b); columnModel.getSelectionModel().addSelectionInterval(a, b); }
    public void removeColumnSelectionInterval(int a, int b) { checkCol(a); checkCol(b); columnModel.getSelectionModel().removeSelectionInterval(a, b); }
    public int getSelectedRow() { return selectionModel.getMinSelectionIndex(); }
    public int getSelectedColumn() { return columnModel.getSelectionModel().getMinSelectionIndex(); }
    public int[] getSelectedRows() {
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
    public int[] getSelectedColumns() { return columnModel.getSelectedColumns(); }
    public int getSelectedRowCount() {
        int iMin = selectionModel.getMinSelectionIndex();
        int iMax = selectionModel.getMaxSelectionIndex();
        int count = 0;
        for (int i = iMin; i <= iMax; i++) if (selectionModel.isSelectedIndex(i)) count++;
        return count;
    }
    public int getSelectedColumnCount() { return columnModel.getSelectedColumnCount(); }
    public boolean isRowSelected(int row) { return selectionModel.isSelectedIndex(row); }
    public boolean isColumnSelected(int column) { return columnModel.getSelectionModel().isSelectedIndex(column); }
    public boolean isCellSelected(int row, int column) {
        if (!getRowSelectionAllowed() && !getColumnSelectionAllowed()) return false;
        return (!getRowSelectionAllowed() || isRowSelected(row)) && (!getColumnSelectionAllowed() || isColumnSelected(column));
    }
    public void addRowSelectionIntervalQuiet(int a, int b) { selectionModel.addSelectionInterval(a, b); }
    private void changeSelectionModel(ListSelectionModel sm, int index, boolean toggle, boolean extend, boolean selected, int anchor, boolean anchorSelected) {
        if (extend) {
            if (toggle) {
                if (anchorSelected) sm.addSelectionInterval(anchor, index); else sm.removeSelectionInterval(anchor, index);
            } else sm.setSelectionInterval(anchor, index);
        } else {
            if (toggle) {
                if (selected) sm.removeSelectionInterval(index, index); else sm.addSelectionInterval(index, index);
            } else sm.setSelectionInterval(index, index);
        }
    }
    public void changeSelection(int rowIndex, int columnIndex, boolean toggle, boolean extend) {
        ListSelectionModel rsm = getSelectionModel();
        ListSelectionModel csm = getColumnModel().getSelectionModel();
        if (rowIndex < 0 || rowIndex >= getRowCount() || columnIndex < 0 || columnIndex >= getColumnCount()) return;
        int anchorRow = rsm.getAnchorSelectionIndex() < getRowCount() ? rsm.getAnchorSelectionIndex() : -1;
        int anchorCol = csm.getAnchorSelectionIndex() < getColumnCount() ? csm.getAnchorSelectionIndex() : -1;
        boolean anchorSelected = true;
        if (anchorRow == -1) { if (getRowCount() > 0) anchorRow = 0; anchorSelected = false; }
        if (anchorCol == -1) { if (getColumnCount() > 0) anchorCol = 0; anchorSelected = false; }
        boolean selected = isCellSelected(rowIndex, columnIndex);
        anchorSelected = anchorSelected && isCellSelected(anchorRow, anchorCol);
        changeSelectionModel(csm, columnIndex, toggle, extend, selected, anchorCol, anchorSelected);
        changeSelectionModel(rsm, rowIndex, toggle, extend, selected, anchorRow, anchorSelected);
        Rectangle cellRect = getCellRect(rowIndex, columnIndex, false);
        scrollRectToVisible(cellRect);
    }
    void clearSelectionAndLeadAnchor() {
        selectionModel.setValueIsAdjusting(true);
        columnModel.getSelectionModel().setValueIsAdjusting(true);
        clearSelection();
        selectionModel.setAnchorSelectionIndex(-1);
        selectionModel.setLeadSelectionIndex(-1);
        columnModel.getSelectionModel().setAnchorSelectionIndex(-1);
        columnModel.getSelectionModel().setLeadSelectionIndex(-1);
        selectionModel.setValueIsAdjusting(false);
        columnModel.getSelectionModel().setValueIsAdjusting(false);
    }
    public void valueChanged(ListSelectionEvent e) { repaint(); }
    // ---- geometrie ----
    public Rectangle getCellRect(int row, int column, boolean includeSpacing) {
        Rectangle r = new Rectangle();
        boolean valid = true;
        if (row < 0) valid = false;
        else if (row >= getRowCount()) { r.y = getHeight(); valid = false; }
        else { r.height = getRowHeight(row); r.y = rowY(row); }
        if (column < 0) { if (!getComponentOrientationLTR()) r.x = getWidth(); valid = false; }
        else if (column >= getColumnCount()) { r.x = getWidth(); valid = false; }
        else {
            TableColumnModel cm = getColumnModel();
            for (int i = 0; i < column; i++) r.x += cm.getColumn(i).getWidth();
            r.width = cm.getColumn(column).getWidth();
        }
        if (valid && !includeSpacing) {
            int rm = Math.min(getRowMargin(), r.height);
            int cm = Math.min(getColumnModel().getColumnMargin(), r.width);
            r.setBounds(r.x + cm / 2, r.y + rm / 2, r.width - cm, r.height - rm);
        }
        return r;
    }
    private boolean getComponentOrientationLTR() { return true; }
    public int rowAtPoint(Point point) {
        int y = point.y;
        int result;
        if (rowHeightMap == null) result = y < 0 ? -1 : y / getRowHeight();
        else {
            result = -1;
            if (y >= 0) {
                int acc = 0, n = getRowCount();
                for (int i = 0; i < n; i++) { acc += getRowHeight(i); if (y < acc) { result = i; break; } }
            }
        }
        if (result < 0) return -1;
        else if (result >= getRowCount()) return -1;
        return result;
    }
    public int columnAtPoint(Point point) {
        int x = point.x;
        if (x < 0) return -1;
        return getColumnModel().getColumnIndexAtX(x);
    }
    public Rectangle getVisibleRowsRect() { return getVisibleRect(); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        long w = 0;
        Enumeration<TableColumn> en = getColumnModel().getColumns();
        while (en.hasMoreElements()) w += en.nextElement().getPreferredWidth();
        int h = 0;
        if (rowHeightMap == null) h = getRowCount() * rowHeight; else h = rowY(getRowCount());
        return new Dimension((int) Math.min(w, Integer.MAX_VALUE), h);
    }
    public Dimension getMinimumSize() { return minSize != null ? new Dimension(minSize) : new Dimension(0, 0); }
    // ---- mise en page des colonnes ----
    TableColumn getResizingColumn() { return tableHeader == null ? null : tableHeader.getResizingColumn(); }
    private int viewIndexForColumn(TableColumn aColumn) {
        TableColumnModel cm = getColumnModel();
        for (int column = 0; column < cm.getColumnCount(); column++) if (cm.getColumn(column) == aColumn) return column;
        return -1;
    }
    public void doLayout() {
        TableColumn resizingColumn = getResizingColumn();
        if (resizingColumn == null) {
            setWidthsFromPreferredWidths(false);
        } else {
            int columnIndex = viewIndexForColumn(resizingColumn);
            int delta = getWidth() - getColumnModel().getTotalColumnWidth();
            accommodateDelta(columnIndex, delta);
            delta = getWidth() - getColumnModel().getTotalColumnWidth();
            if (delta != 0) resizingColumn.setWidth(resizingColumn.getWidth() + delta);
        }
        super.doLayout();
    }
    private void accommodateDelta(int resizingColumnIndex, int delta) {
        int columnCount = getColumnCount();
        int from = resizingColumnIndex;
        int to;
        switch (autoResizeMode) {
            case AUTO_RESIZE_NEXT_COLUMN: from = from + 1; to = Math.min(from + 1, columnCount); break;
            case AUTO_RESIZE_SUBSEQUENT_COLUMNS: from = from + 1; to = columnCount; break;
            case AUTO_RESIZE_LAST_COLUMN: from = columnCount - 1; to = from + 1; break;
            case AUTO_RESIZE_ALL_COLUMNS: from = 0; to = columnCount; break;
            default: return;
        }
        final int start = from;
        final int end = to;
        final TableColumnModel cm = columnModel;
        int count = end - start;
        if (count <= 0) return;
        int[] lower = new int[count], upper = new int[count], mid = new int[count];
        long totalWidth = 0;
        for (int i = 0; i < count; i++) {
            TableColumn c = cm.getColumn(i + start);
            lower[i] = c.getMinWidth(); upper[i] = c.getMaxWidth(); mid[i] = c.getWidth();
            totalWidth += c.getWidth();
        }
        int[] res = adjustSizes(totalWidth + delta, lower, mid, upper, false);
        for (int i = 0; i < count; i++) cm.getColumn(i + start).setWidth(res[i]);
    }
    private void setWidthsFromPreferredWidths(final boolean inverse) {
        int totalWidth = getWidth();
        final TableColumnModel cm = columnModel;
        int n = cm.getColumnCount();
        if (n == 0) return;
        int[] lower = new int[n], upper = new int[n], mid = new int[n];
        long totalPreferred = 0;
        for (int i = 0; i < n; i++) {
            TableColumn c = cm.getColumn(i);
            lower[i] = c.getMinWidth(); upper[i] = c.getMaxWidth();
            mid[i] = inverse ? c.getWidth() : c.getPreferredWidth();
            totalPreferred += c.getPreferredWidth();
        }
        long target = !inverse ? totalWidth : totalPreferred;
        int[] res = adjustSizes(target, lower, mid, upper, inverse);
        for (int i = 0; i < n; i++) {
            if (!inverse) cm.getColumn(i).setWidth(res[i]); else cm.getColumn(i).setPreferredWidth(res[i]);
        }
    }
    private static int[] adjustSizes(long target, int[] lower, int[] mid, int[] upper, boolean inverse) {
        int n = mid.length;
        long totalMid = 0;
        for (int i = 0; i < n; i++) totalMid += mid[i];
        int[] lo, hi;
        if ((target < totalMid) == !inverse) { lo = lower; hi = mid; }
        else { lo = mid; hi = upper; }
        return adjustRange(target, lo, hi, !inverse, n);
    }
    private static int[] adjustRange(long target, int[] lo, int[] hi, boolean limitToRange, int n) {
        long totalLowerBound = 0, totalUpperBound = 0;
        for (int i = 0; i < n; i++) { totalLowerBound += lo[i]; totalUpperBound += hi[i]; }
        if (limitToRange) target = Math.min(Math.max(totalLowerBound, target), totalUpperBound);
        int[] out = new int[n];
        for (int i = 0; i < n; i++) {
            int lowerBound = lo[i], upperBound = hi[i];
            int newSize;
            if (totalLowerBound == totalUpperBound) newSize = lowerBound;
            else {
                double f = (double) (target - totalLowerBound) / (totalUpperBound - totalLowerBound);
                newSize = (int) Math.round(lowerBound + f * (upperBound - lowerBound));
            }
            out[i] = newSize;
            target -= newSize;
            totalLowerBound -= lowerBound;
            totalUpperBound -= upperBound;
        }
        return out;
    }
    public void sizeColumnsToFit(int resizingColumn) { setWidthsFromPreferredWidths(false); }
    protected void resizeAndRepaint() { revalidate(); repaint(); }
    // ---- scrollable ----
    public int getScrollableUnitIncrement(Rectangle visibleRect, int orientation, int direction) {
        int leadingRow, leadingCol;
        Rectangle leadingCell;
        if (orientation == SwingConstants.HORIZONTAL) {
            leadingCol = columnAtPoint(new Point(visibleRect.x, 0));
            if (leadingCol < 0) return 0;
            leadingCell = getCellRect(0, leadingCol, true);
            if (leadingCell.x < visibleRect.x) {
                if (direction > 0) return leadingCell.x + leadingCell.width - visibleRect.x;
                return visibleRect.x - leadingCell.x;
            }
            if (direction > 0) return leadingCell.width;
            if (leadingCol > 0) return getCellRect(0, leadingCol - 1, true).width;
            return 0;
        }
        leadingRow = rowAtPoint(new Point(0, visibleRect.y));
        if (leadingRow < 0) return getRowHeight();
        leadingCell = getCellRect(leadingRow, 0, true);
        if (leadingCell.y < visibleRect.y) {
            if (direction > 0) return leadingCell.y + leadingCell.height - visibleRect.y;
            return visibleRect.y - leadingCell.y;
        }
        if (direction > 0) return leadingCell.height;
        if (leadingRow > 0) return getRowHeight(leadingRow - 1);
        return 0;
    }
    public int getScrollableBlockIncrement(Rectangle visibleRect, int orientation, int direction) {
        if (orientation == SwingConstants.VERTICAL) return visibleRect.height;
        return visibleRect.width;
    }
    public boolean getScrollableTracksViewportWidth() { return autoResizeMode != AUTO_RESIZE_OFF; }
    public boolean getScrollableTracksViewportHeight() {
        Container p = getParent();
        return getFillsViewportHeight() && p instanceof JViewport && p.getHeight() > getPreferredSize().height;
    }
    // ---- evenements du modele ----
    public void tableChanged(TableModelEvent e) {
        if (e == null || e.getFirstRow() == TableModelEvent.HEADER_ROW) {
            if (isEditing()) removeEditor();
            clearSelectionAndLeadAnchor();
            if (sorter != null) { ignoreSort = true; try { sorter.modelStructureChanged(); } finally { ignoreSort = false; } }
            if (getAutoCreateColumnsFromModel()) createDefaultColumnsFromModel(); else resizeAndRepaint();
            return;
        }
        if (sorter != null) { sortedTableChanged(e); return; }
        if (e.getType() == TableModelEvent.INSERT) { tableRowsInserted(e); return; }
        if (e.getType() == TableModelEvent.DELETE) { tableRowsDeleted(e); return; }
        if (e.getLastRow() == Integer.MAX_VALUE) {
            if (isEditing()) removeEditor();
            clearSelectionAndLeadAnchor();
            resizeAndRepaint();
        } else repaint();
    }
    private void tableRowsInserted(TableModelEvent e) {
        if (isEditing()) removeEditor();
        int start = e.getFirstRow(), end = e.getLastRow();
        if (start < 0) start = 0;
        if (end < 0) end = getRowCount() - 1;
        int length = end - start + 1;
        selectionModel.insertIndexInterval(start, length, true);
        resizeAndRepaint();
    }
    private void tableRowsDeleted(TableModelEvent e) {
        if (isEditing()) removeEditor();
        int start = e.getFirstRow(), end = e.getLastRow();
        if (start < 0) start = 0;
        if (end < 0) end = getRowCount() - 1;
        selectionModel.removeIndexInterval(start, end);
        resizeAndRepaint();
    }
    private void sortedTableChanged(TableModelEvent e) {
        if (isEditing()) removeEditor();
        // lignes selectionnees converties en lignes du modele, avec l'ancienne correspondance
        ArrayList<Integer> sel = new ArrayList<>();
        int oldCount = sorter.getViewRowCount();
        if (e.getLastRow() != Integer.MAX_VALUE || e.getType() != TableModelEvent.UPDATE) {
            for (int v : getSelectedRows()) {
                if (v < oldCount) { try { sel.add(sorter.convertRowIndexToModel(v)); } catch (IndexOutOfBoundsException ex) { } }
            }
        }
        int first = e.getFirstRow(), last = e.getLastRow();
        ArrayList<Integer> mapped = new ArrayList<>();
        for (int m : sel) {
            if (e.getType() == TableModelEvent.INSERT) { if (m >= first) m += last - first + 1; mapped.add(m); }
            else if (e.getType() == TableModelEvent.DELETE) { if (m >= first && m <= last) continue; if (m > last) m -= last - first + 1; mapped.add(m); }
            else mapped.add(m);
        }
        ignoreSort = true;
        try {
            if (e.getType() == TableModelEvent.INSERT) sorter.rowsInserted(first, last);
            else if (e.getType() == TableModelEvent.DELETE) sorter.rowsDeleted(first, last);
            else if (e.getLastRow() == Integer.MAX_VALUE) sorter.allRowsChanged();
            else if (e.getColumn() == TableModelEvent.ALL_COLUMNS) sorter.rowsUpdated(first, last);
            else sorter.rowsUpdated(first, last, e.getColumn());
        } finally { ignoreSort = false; }
        selectionModel.setValueIsAdjusting(true);
        selectionModel.clearSelection();
        selectionModel.setAnchorSelectionIndex(-1);
        selectionModel.setLeadSelectionIndex(-1);
        for (int m : mapped) {
            if (m < 0 || m >= getModel().getRowCount()) continue;
            int v = sorter.convertRowIndexToView(m);
            if (v >= 0) selectionModel.addSelectionInterval(v, v);
        }
        selectionModel.setValueIsAdjusting(false);
        resizeAndRepaint();
    }
    public void sorterChanged(RowSorterEvent e) {
        if (e.getType() == RowSorterEvent.Type.SORT_ORDER_CHANGED) {
            if (tableHeader != null) tableHeader.repaint();
        } else if (e.getType() == RowSorterEvent.Type.SORTED && !ignoreSort) {
            if (isEditing()) removeEditor();
            ArrayList<Integer> sel = new ArrayList<>();
            for (int v : getSelectedRows()) {
                int m = e.convertPreviousRowIndexToModel(v);
                if (m >= 0) sel.add(m);
            }
            selectionModel.setValueIsAdjusting(true);
            selectionModel.clearSelection();
            selectionModel.setAnchorSelectionIndex(-1);
            selectionModel.setLeadSelectionIndex(-1);
            for (int m : sel) {
                int v = sorter.convertRowIndexToView(m);
                if (v >= 0) selectionModel.addSelectionInterval(v, v);
            }
            selectionModel.setValueIsAdjusting(false);
            resizeAndRepaint();
            if (tableHeader != null) tableHeader.repaint();
        }
    }
    public void columnAdded(TableColumnModelEvent e) { if (isEditing()) removeEditor(); resizeAndRepaint(); }
    public void columnRemoved(TableColumnModelEvent e) { if (isEditing()) removeEditor(); resizeAndRepaint(); }
    public void columnMoved(TableColumnModelEvent e) {
        if (isEditing() && !getCellEditor().stopCellEditing()) getCellEditor().cancelCellEditing();
        repaint();
    }
    public void columnMarginChanged(ChangeEvent e) {
        if (isEditing() && !getCellEditor().stopCellEditing()) getCellEditor().cancelCellEditing();
        TableColumn resizingColumn = getResizingColumn();
        if (resizingColumn != null && autoResizeMode == AUTO_RESIZE_OFF) resizingColumn.setPreferredWidth(resizingColumn.getWidth());
        resizeAndRepaint();
    }
    public void columnSelectionChanged(ListSelectionEvent e) { repaint(); }
    // ---- rendu ----
    protected void createDefaultRenderers() {
        defaultRenderersByColumnClass = new HashMap<>();
        defaultRenderersByColumnClass.put(Object.class, new DefaultTableCellRenderer.UIResource());
        defaultRenderersByColumnClass.put(Number.class, new NumberRenderer());
        defaultRenderersByColumnClass.put(Float.class, new DoubleRenderer());
        defaultRenderersByColumnClass.put(Double.class, new DoubleRenderer());
        defaultRenderersByColumnClass.put(java.util.Date.class, new DateRenderer());
        defaultRenderersByColumnClass.put(Icon.class, new IconRenderer());
        defaultRenderersByColumnClass.put(ImageIcon.class, new IconRenderer());
        defaultRenderersByColumnClass.put(Boolean.class, new BooleanRenderer());
    }
    static class NumberRenderer extends DefaultTableCellRenderer.UIResource {
        public NumberRenderer() { super(); setHorizontalAlignment(JLabel.RIGHT); }
    }
    static class DoubleRenderer extends NumberRenderer {
        NumberFormat formatter;
        public DoubleRenderer() { super(); }
        public void setValue(Object value) {
            if (formatter == null) formatter = NumberFormat.getInstance();
            setText((value == null) ? "" : formatter.format(value));
        }
    }
    static class DateRenderer extends DefaultTableCellRenderer.UIResource {
        java.text.DateFormat formatter;
        public DateRenderer() { super(); }
        public void setValue(Object value) {
            if (formatter == null) formatter = java.text.DateFormat.getDateInstance();
            setText((value == null) ? "" : formatter.format(value));
        }
    }
    static class IconRenderer extends DefaultTableCellRenderer.UIResource {
        public IconRenderer() { super(); setHorizontalAlignment(JLabel.CENTER); }
        public void setValue(Object value) { setIcon((value instanceof Icon) ? (Icon) value : null); setText(""); }
    }
    static class BooleanRenderer extends JCheckBox implements javax.swing.table.TableCellRenderer, javax.swing.plaf.UIResource {
        public BooleanRenderer() { super(); opaque = true; }
        public Component getTableCellRendererComponent(JTable table, Object value, boolean isSelected, boolean hasFocus, int row, int column) {
            if (isSelected) { setForeground(table.getSelectionForeground()); setBackground(table.getSelectionBackground()); }
            else { setForeground(table.getForeground()); setBackground(table.getBackground()); }
            selected = (value != null && ((Boolean) value).booleanValue());
            hasFocusBorder = hasFocus;
            return this;
        }
        boolean hasFocusBorder;
        protected void paintComponent(Graphics g) {
            g.setColor(getBackground());
            g.fillRect(0, 0, width, height);
            int bx = (width - 13) / 2, by = (height - 13) / 2;
            AbstractButton.gradient(g, bx + 1, by + 1, 12, 12, false, false);
            g.setColor(new Color(122, 138, 153));
            g.drawRect(bx, by, 12, 12);
            if (selected) {
                g.setColor(new Color(51, 51, 51));
                g.drawLine(bx + 3, by + 6, bx + 5, by + 9); g.drawLine(bx + 4, by + 6, bx + 6, by + 9);
                g.drawLine(bx + 6, by + 9, bx + 10, by + 3); g.drawLine(bx + 5, by + 9, bx + 9, by + 3);
            }
            if (hasFocusBorder) { g.setColor(new Color(115, 164, 209)); g.drawRect(0, 0, width - 1, height - 1); }
        }
    }
    public void setDefaultRenderer(Class<?> columnClass, TableCellRenderer renderer) {
        if (renderer != null) defaultRenderersByColumnClass.put(columnClass, renderer);
        else defaultRenderersByColumnClass.remove(columnClass);
    }
    public TableCellRenderer getDefaultRenderer(Class<?> columnClass) {
        if (columnClass == null) return null;
        TableCellRenderer r = defaultRenderersByColumnClass.get(columnClass);
        if (r != null) return r;
        Class<?> s = columnClass.getSuperclass();
        if (s == null && columnClass != Object.class) s = Object.class;
        return getDefaultRenderer(s);
    }
    public TableCellRenderer getCellRenderer(int row, int column) {
        TableColumn tableColumn = getColumnModel().getColumn(column);
        TableCellRenderer renderer = tableColumn.getCellRenderer();
        if (renderer == null) renderer = getDefaultRenderer(getColumnClass(column));
        return renderer;
    }
    public Component prepareRenderer(TableCellRenderer renderer, int row, int column) {
        Object value = getValueAt(row, column);
        boolean isSelected = false;
        boolean hasFocus = false;
        if (!isPaintingForPrint()) {
            isSelected = isCellSelected(row, column);
            boolean rowIsLead = (selectionModel.getLeadSelectionIndex() == row);
            boolean colIsLead = (columnModel.getSelectionModel().getLeadSelectionIndex() == column);
            hasFocus = (rowIsLead && colIsLead) && isFocusOwner();
        }
        Component c = renderer.getTableCellRendererComponent(this, value, isSelected, hasFocus, row, column);
        JComponent.attach(c, this);
        return c;
    }
    private boolean isPaintingForPrint() { return false; }
    // ---- edition ----
    protected void createDefaultEditors() {
        defaultEditorsByColumnClass = new HashMap<>();
        defaultEditorsByColumnClass.put(Object.class, new GenericEditor());
        defaultEditorsByColumnClass.put(Number.class, new NumberEditor());
        defaultEditorsByColumnClass.put(Boolean.class, new BooleanEditor());
    }
    static class GenericEditor extends DefaultCellEditor {
        Class<?> type;
        Object value;
        public GenericEditor() { super(new JTextField()); getComponent().setName("Table.editor"); }
        public boolean stopCellEditing() {
            String s = (String) super.getCellEditorValue();
            if ("".equals(s)) {
                if (type == null || type == String.class || type == Object.class) value = s; else value = null;
                return super.stopCellEditing();
            }
            try { value = convert(type, s); }
            catch (Exception e) { ((JComponent) getComponent()).setBorder(new LineBorder(Color.red)); return false; }
            return super.stopCellEditing();
        }
        static Object convert(Class<?> t, String s) throws Exception {
            if (t == null || t == Object.class || t == String.class) return s;
            if (t == Integer.class) return Integer.valueOf(s.trim());
            if (t == Long.class) return Long.valueOf(s.trim());
            if (t == Double.class) return Double.valueOf(s.trim());
            if (t == Float.class) return Float.valueOf(s.trim());
            if (t == Short.class) return Short.valueOf(s.trim());
            if (t == Byte.class) return Byte.valueOf(s.trim());
            if (t == Boolean.class) return Boolean.valueOf(s.trim());
            if (t == Character.class) { if (s.length() != 1) throw new IllegalArgumentException(s); return Character.valueOf(s.charAt(0)); }
            if (t == Number.class) { try { return Integer.valueOf(s.trim()); } catch (NumberFormatException e) { return Double.valueOf(s.trim()); } }
            if (t == java.math.BigDecimal.class) return new java.math.BigDecimal(s.trim());
            if (t == java.math.BigInteger.class) return new java.math.BigInteger(s.trim());
            return t.getConstructor(String.class).newInstance(s);
        }
        public Component getTableCellEditorComponent(JTable table, Object value, boolean isSelected, int row, int column) {
            this.value = null;
            ((JComponent) getComponent()).setBorder(new LineBorder(Color.black));
            Class<?> ct = table.getColumnClass(column);
            type = ct == Object.class ? String.class : ct;
            if (value != null && ct == Object.class) type = value.getClass();
            return super.getTableCellEditorComponent(table, value, isSelected, row, column);
        }
        public Object getCellEditorValue() { return value; }
    }
    static class NumberEditor extends GenericEditor {
        public NumberEditor() { ((JTextField) getComponent()).setHorizontalAlignment(SwingConstants.RIGHT); }
    }
    static class BooleanEditor extends DefaultCellEditor {
        public BooleanEditor() { super(new JCheckBox()); JCheckBox checkBox = (JCheckBox) getComponent(); checkBox.setHorizontalAlignment(JCheckBox.CENTER); }
    }
    public void setDefaultEditor(Class<?> columnClass, TableCellEditor editor) {
        if (editor != null) defaultEditorsByColumnClass.put(columnClass, editor);
        else defaultEditorsByColumnClass.remove(columnClass);
    }
    public TableCellEditor getDefaultEditor(Class<?> columnClass) {
        if (columnClass == null) return null;
        TableCellEditor e = defaultEditorsByColumnClass.get(columnClass);
        if (e != null) return e;
        Class<?> s = columnClass.getSuperclass();
        if (s == null && columnClass != Object.class) s = Object.class;
        return getDefaultEditor(s);
    }
    public TableCellEditor getCellEditor(int row, int column) {
        TableColumn tableColumn = getColumnModel().getColumn(column);
        TableCellEditor editor = tableColumn.getCellEditor();
        if (editor == null) editor = getDefaultEditor(getColumnClass(column));
        return editor;
    }
    public Component prepareEditor(TableCellEditor editor, int row, int column) {
        Object value = getValueAt(row, column);
        boolean isSelected = isCellSelected(row, column);
        return editor.getTableCellEditorComponent(this, value, isSelected, row, column);
    }
    public boolean isEditing() { return cellEditor != null; }
    public Component getEditorComponent() { return editorComp; }
    public TableCellEditor getCellEditor() { return cellEditor; }
    public void setCellEditor(TableCellEditor anEditor) { TableCellEditor old = cellEditor; cellEditor = anEditor; firePropertyChange("tableCellEditor", old, anEditor); }
    public void setEditingColumn(int aColumn) { editingColumn = aColumn; }
    public void setEditingRow(int aRow) { editingRow = aRow; }
    public int getEditingColumn() { return editingColumn; }
    public int getEditingRow() { return editingRow; }
    public boolean editCellAt(int row, int column) { return editCellAt(row, column, null); }
    public boolean editCellAt(int row, int column, EventObject e) {
        if (cellEditor != null && !cellEditor.stopCellEditing()) return false;
        if (row < 0 || row >= getRowCount() || column < 0 || column >= getColumnCount()) return false;
        if (!isCellEditable(row, column)) return false;
        TableCellEditor editor = getCellEditor(row, column);
        if (editor != null && editor.isCellEditable(e)) {
            editorComp = prepareEditor(editor, row, column);
            if (editorComp == null) { removeEditor(); return false; }
            editorComp.setBounds(getCellRect(row, column, false));
            add(editorComp);
            editorComp.invalidate();
            if (editorComp instanceof Container) ((Container) editorComp).validate();
            setCellEditor(editor);
            setEditingRow(row);
            setEditingColumn(column);
            editor.addCellEditorListener(this);
            installEditorKeys(editorComp);
            editorComp.requestFocus();
            repaint();
            return true;
        }
        return false;
    }
    private void installEditorKeys(Component c) {
        editorKeys = new KeyAdapter() {
            public void keyPressed(KeyEvent e) {
                if (e.getKeyCode() == KeyEvent.VK_ESCAPE) {
                    if (cellEditor != null) cellEditor.cancelCellEditing();
                    e.consume();
                } else if (e.getKeyCode() == KeyEvent.VK_TAB) {
                    TableCellEditor ed = cellEditor;
                    if (ed != null && ed.stopCellEditing()) { moveLead(0, 1, true); }
                    e.consume();
                }
            }
        };
        c.addKeyListener(editorKeys);
    }
    public void removeEditor() {
        TableCellEditor editor = getCellEditor();
        if (editor != null) {
            editor.removeCellEditorListener(this);
            if (editorComp != null) {
                if (editorKeys != null) editorComp.removeKeyListener(editorKeys);
                boolean hadFocus = editorComp.isFocusOwner() || editorComp instanceof Container && ((Container) editorComp).getComponentCount() >= 0 && editorComp.isFocusOwner();
                remove(editorComp);
                if (hadFocus) requestFocus();
            }
            setCellEditor(null);
            setEditingColumn(-1);
            setEditingRow(-1);
            editorComp = null;
            editorKeys = null;
            repaint();
        }
    }
    public void editingStopped(ChangeEvent e) {
        TableCellEditor editor = getCellEditor();
        if (editor != null) {
            Object value = editor.getCellEditorValue();
            int r = editingRow, c = editingColumn;
            removeEditor();
            if (r >= 0 && c >= 0 && r < getRowCount()) setValueAt(value, r, c);
        }
    }
    public void editingCanceled(ChangeEvent e) { removeEditor(); }
    // ---- evenements souris / clavier ----
    public boolean wantsMouse() { return true; }
    public boolean wantsKeys() { return true; }
    public boolean focusTraversable() { return true; }
    public boolean consumesTab() { return true; }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (!enabled) return;
        int id = e.getID();
        if (id == MouseEvent.MOUSE_PRESSED && e.getButton() == 1) {
            Point p = e.getPoint();
            pressedRow = rowAtPoint(p);
            pressedCol = columnAtPoint(p);
            if (pressedRow < 0 || pressedCol < 0) {
                if (isEditing() && !cellEditor.stopCellEditing()) cellEditor.cancelCellEditing();
                requestFocus();
                return;
            }
            if (isEditing() && (editingRow != pressedRow || editingColumn != pressedCol) && !cellEditor.stopCellEditing()) cellEditor.cancelCellEditing();
            boolean started = false;
            if (!(isEditing() && editingRow == pressedRow && editingColumn == pressedCol)) {
                started = editCellAt(pressedRow, pressedCol, e);
                if (started) {
                    // re-poste le clic sur l'editeur (case a cocher, liste deroulante)
                    Component ec = editorComp;
                    if (ec instanceof JCheckBox) ((JCheckBox) ec).doClick();
                    else if (ec instanceof JComboBox) {
                        MouseEvent me = new MouseEvent(ec, MouseEvent.MOUSE_PRESSED, e.getWhen(), e.getModifiersEx(), 2, 2, e.getClickCount(), false, 1);
                        ec.dispatchEvent(me);
                    }
                } else requestFocus();
            }
            CellEditor ed = getCellEditor();
            if (!started || ed == null || ed.shouldSelectCell(e)) {
                selectionModel.setValueIsAdjusting(true);
                columnModel.getSelectionModel().setValueIsAdjusting(true);
                changeSelection(pressedRow, pressedCol, e.isControlDown(), e.isShiftDown());
                dragAnchorRow = pressedRow;
            }
        } else if (id == MouseEvent.MOUSE_RELEASED) {
            selectionModel.setValueIsAdjusting(false);
            columnModel.getSelectionModel().setValueIsAdjusting(false);
            dragAnchorRow = -1;
        }
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        super.processMouseMotionEvent(e);
        if (e.getID() == MouseEvent.MOUSE_DRAGGED && enabled && dragAnchorRow >= 0 && !isEditing()) {
            Point p = e.getPoint();
            int row = rowAtPoint(p), col = columnAtPoint(p);
            if (row < 0) row = p.y < 0 ? 0 : getRowCount() - 1;
            if (col < 0) col = p.x < 0 ? 0 : getColumnCount() - 1;
            if (row >= 0 && col >= 0) changeSelection(row, col, false, true);
        }
    }
    private void moveLead(int dr, int dc, boolean wrap) {
        int rows = getRowCount(), cols = getColumnCount();
        if (rows == 0 || cols == 0) return;
        int r = selectionModel.getLeadSelectionIndex(), c = columnModel.getSelectionModel().getLeadSelectionIndex();
        if (r < 0) r = 0;
        if (c < 0) c = 0;
        r += dr; c += dc;
        if (wrap) {
            if (c >= cols) { c = 0; r++; } else if (c < 0) { c = cols - 1; r--; }
            if (r >= rows) r = 0; else if (r < 0) r = rows - 1;
        }
        r = Math.max(0, Math.min(rows - 1, r));
        c = Math.max(0, Math.min(cols - 1, c));
        changeSelection(r, c, false, false);
        requestFocus();
    }
    protected void processKeyEvent(KeyEvent e) {
        super.processKeyEvent(e);
        if (e.isConsumed() || !enabled) return;
        int id = e.getID();
        if (id == KeyEvent.KEY_TYPED) {
            char ch = e.getKeyChar();
            if (!isEditing() && ch >= 32 && ch != 127) {
                int r = selectionModel.getLeadSelectionIndex(), c = columnModel.getSelectionModel().getLeadSelectionIndex();
                if (r >= 0 && c >= 0 && editCellAt(r, c, e)) {
                    Component ec = editorComp;
                    if (ec != null) ec.dispatchEvent(new KeyEvent(ec, KeyEvent.KEY_TYPED, e.getWhen(), 0, KeyEvent.VK_UNDEFINED, ch));
                }
                e.consume();
            }
            return;
        }
        if (id != KeyEvent.KEY_PRESSED) return;
        int rows = getRowCount();
        int pageRows = Math.max(1, getVisibleRect().height / Math.max(1, getRowHeight()) - 1);
        switch (e.getKeyCode()) {
            case KeyEvent.VK_UP: moveLead(-1, 0, false); break;
            case KeyEvent.VK_DOWN: moveLead(1, 0, false); break;
            case KeyEvent.VK_LEFT: moveLead(0, -1, false); break;
            case KeyEvent.VK_RIGHT: moveLead(0, 1, false); break;
            case KeyEvent.VK_PAGE_UP: moveLead(-pageRows, 0, false); break;
            case KeyEvent.VK_PAGE_DOWN: moveLead(pageRows, 0, false); break;
            case KeyEvent.VK_HOME: if (rows > 0) changeSelection(0, 0, false, false); break;
            case KeyEvent.VK_END: if (rows > 0) changeSelection(rows - 1, getColumnCount() - 1, false, false); break;
            case KeyEvent.VK_ENTER: moveLead(1, 0, true); break;
            case KeyEvent.VK_TAB: moveLead(0, 1, true); break;
            case KeyEvent.VK_F2: {
                int r = selectionModel.getLeadSelectionIndex(), c = columnModel.getSelectionModel().getLeadSelectionIndex();
                if (r >= 0 && c >= 0) editCellAt(r, c, null);
                break;
            }
            case KeyEvent.VK_A:
                if (e.isControlDown()) { selectAll(); break; }
                return;
            case KeyEvent.VK_ESCAPE: return;
            default: return;
        }
        e.consume();
    }
    protected void paintComponent(Graphics g) {
        g.setColor(getBackground());
        g.fillRect(0, 0, width, height);
        int rowCount = getRowCount(), colCount = getColumnCount();
        if (rowCount <= 0 || colCount <= 0) return;
        Rectangle clip = g.getClipBounds();
        if (clip == null) clip = new Rectangle(0, 0, width, height);
        int rMin = rowAtPoint(new Point(0, clip.y));
        int rMax = rowAtPoint(new Point(0, clip.y + clip.height - 1));
        if (rMin == -1) rMin = 0;
        if (rMax == -1) rMax = rowCount - 1;
        int cMin = columnAtPoint(new Point(clip.x, 0));
        int cMax = columnAtPoint(new Point(clip.x + clip.width - 1, 0));
        if (cMin == -1) cMin = 0;
        if (cMax == -1) cMax = colCount - 1;
        // cellules
        for (int row = rMin; row <= rMax; row++) {
            Rectangle cell = getCellRect(row, cMin, false);
            for (int col = cMin; col <= cMax; col++) {
                int cw = columnModel.getColumn(col).getWidth();
                cell.width = cw - Math.min(columnModel.getColumnMargin(), cw);
                if (!(editorComp != null && editingRow == row && editingColumn == col)) {
                    TableCellRenderer renderer = getCellRenderer(row, col);
                    Component comp = prepareRenderer(renderer, row, col);
                    JComponent.paintCell(g, comp, this, cell.x, cell.y, cell.width, cell.height);
                }
                cell.x += cw;
            }
        }
        // grille
        g.setColor(gridColor);
        if (showHorizontalLines) {
            int y = rowY(rMin);
            int x2 = getColumnModel().getTotalColumnWidth();
            for (int row = rMin; row <= rMax; row++) {
                y += getRowHeight(row);
                g.drawLine(0, y - 1, x2 - 1, y - 1);
            }
        }
        if (showVerticalLines) {
            int x = 0;
            for (int c = 0; c < cMin; c++) x += columnModel.getColumn(c).getWidth();
            int y2 = rowY(rMax + 1);
            for (int c = cMin; c <= cMax; c++) {
                x += columnModel.getColumn(c).getWidth();
                g.drawLine(x - 1, 0, x - 1, y2 - 1);
            }
        }
    }
    protected void paintChildren(Graphics g) { super.paintChildren(g); }
}
