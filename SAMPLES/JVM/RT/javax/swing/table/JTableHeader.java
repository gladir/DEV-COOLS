package javax.swing.table;
import java.awt.*;
import java.awt.event.*;
import java.util.Enumeration;
import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;
public class JTableHeader extends JComponent implements TableColumnModelListener {
    protected JTable table;
    protected TableColumnModel columnModel;
    protected boolean reorderingAllowed;
    protected boolean resizingAllowed;
    protected boolean updateTableInRealTime;
    protected transient TableColumn resizingColumn;
    protected transient TableColumn draggedColumn;
    protected transient int draggedDistance;
    private TableCellRenderer defaultRenderer;
    private int mouseXOffset;
    private boolean movedOrResized;
    public JTableHeader() { this(null); }
    public JTableHeader(TableColumnModel cm) {
        super();
        opaque = true;
        if (cm == null) cm = createDefaultColumnModel();
        setColumnModel(cm);
        initializeLocalVars();
    }
    public void setTable(JTable table) { JTable old = this.table; this.table = table; firePropertyChange("table", old, table); }
    public JTable getTable() { return table; }
    public void setReorderingAllowed(boolean b) { boolean old = reorderingAllowed; reorderingAllowed = b; firePropertyChange("reorderingAllowed", old, b); }
    public boolean getReorderingAllowed() { return reorderingAllowed; }
    public void setResizingAllowed(boolean b) { boolean old = resizingAllowed; resizingAllowed = b; firePropertyChange("resizingAllowed", old, b); }
    public boolean getResizingAllowed() { return resizingAllowed; }
    public TableColumn getDraggedColumn() { return draggedColumn; }
    public int getDraggedDistance() { return draggedDistance; }
    public TableColumn getResizingColumn() { return resizingColumn; }
    public void setUpdateTableInRealTime(boolean flag) { updateTableInRealTime = flag; }
    public boolean getUpdateTableInRealTime() { return updateTableInRealTime; }
    public void setDefaultRenderer(TableCellRenderer defaultRenderer) { this.defaultRenderer = defaultRenderer; repaint(); }
    public TableCellRenderer getDefaultRenderer() { return defaultRenderer; }
    public int columnAtPoint(Point point) {
        int x = point.x;
        return getColumnModel().getColumnIndexAtX(x);
    }
    public Rectangle getHeaderRect(int column) {
        Rectangle r = new Rectangle();
        TableColumnModel cm = getColumnModel();
        r.height = getHeight();
        if (column < 0) { r.width = 0; }
        else if (column >= cm.getColumnCount()) { r.x = getWidth(); }
        else {
            for (int i = 0; i < column; i++) r.x += cm.getColumn(i).getWidth();
            r.width = cm.getColumn(column).getWidth();
        }
        return r;
    }
    public void setDraggedColumn(TableColumn aColumn) { draggedColumn = aColumn; }
    public void setDraggedDistance(int distance) { draggedDistance = distance; repaint(); }
    public void setResizingColumn(TableColumn aColumn) { resizingColumn = aColumn; }
    public void setColumnModel(TableColumnModel columnModel) {
        if (columnModel == null) throw new IllegalArgumentException("Cannot set a null ColumnModel");
        TableColumnModel old = this.columnModel;
        if (columnModel != old) {
            if (old != null) old.removeColumnModelListener(this);
            this.columnModel = columnModel;
            columnModel.addColumnModelListener(this);
            firePropertyChange("columnModel", old, columnModel);
            invalidate();
            repaint();
        }
    }
    public TableColumnModel getColumnModel() { return columnModel; }
    public void columnAdded(TableColumnModelEvent e) { resizeAndRepaint(); }
    public void columnRemoved(TableColumnModelEvent e) { resizeAndRepaint(); }
    public void columnMoved(TableColumnModelEvent e) { repaint(); }
    public void columnMarginChanged(ChangeEvent e) { resizeAndRepaint(); }
    public void columnSelectionChanged(ListSelectionEvent e) { }
    protected TableColumnModel createDefaultColumnModel() { return new DefaultTableColumnModel(); }
    protected TableCellRenderer createDefaultRenderer() { return new HeaderRenderer(); }
    protected void initializeLocalVars() {
        setOpaque(true);
        table = null;
        reorderingAllowed = true;
        resizingAllowed = true;
        draggedColumn = null;
        draggedDistance = 0;
        resizingColumn = null;
        updateTableInRealTime = true;
        TableCellRenderer renderer = createDefaultRenderer();
        setDefaultRenderer(renderer);
    }
    public void resizeAndRepaint() { revalidate(); repaint(); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        int height = 0;
        int columnCount = columnModel.getColumnCount();
        long width = 0;
        for (int column = 0; column < columnCount; column++) {
            TableColumn aColumn = columnModel.getColumn(column);
            Component comp = renderer(aColumn, column);
            int rendererHeight = comp.getPreferredSize().height;
            height = Math.max(height, rendererHeight);
            width += aColumn.getPreferredWidth();
        }
        if (height == 0) height = 19;
        return new Dimension((int) Math.min(width, Integer.MAX_VALUE), height);
    }
    private Component renderer(TableColumn aColumn, int column) {
        TableCellRenderer renderer = aColumn.getHeaderRenderer();
        if (renderer == null) renderer = getDefaultRenderer();
        Component c = renderer.getTableCellRendererComponent(getTable(), aColumn.getHeaderValue(), false, false, -1, column);
        JComponent.attach(c, this);
        return c;
    }
    // ---- evenements ----
    public boolean wantsMouse() { return true; }
    private TableColumn getResizingColumn(Point p, int column) {
        if (column == -1) return null;
        Rectangle r = getHeaderRect(column);
        r.x += 3; r.width -= 6;
        if (r.contains(p)) return null;
        int midPoint = r.x + r.width / 2;
        int columnIndex = (p.x < midPoint) ? column - 1 : column;
        if (columnIndex == -1) return null;
        return getColumnModel().getColumn(columnIndex);
    }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (!enabled) return;
        int id = e.getID();
        if (id == MouseEvent.MOUSE_PRESSED && e.getButton() == 1) {
            setDraggedColumn(null);
            setResizingColumn(null);
            setDraggedDistance(0);
            movedOrResized = false;
            Point p = e.getPoint();
            int index = columnAtPoint(p);
            if (index != -1) {
                TableColumn rc = getResizingColumn(p, index);
                if (rc != null && getResizingAllowed() && rc.getResizable()) {
                    setResizingColumn(rc);
                    mouseXOffset = p.x - rc.getWidth();
                } else if (getReorderingAllowed()) {
                    setDraggedColumn(getColumnModel().getColumn(index));
                    mouseXOffset = p.x;
                }
            }
        } else if (id == MouseEvent.MOUSE_RELEASED) {
            setDraggedDistance(0);
            setResizingColumn(null);
            setDraggedColumn(null);
            repaint();
        } else if (id == MouseEvent.MOUSE_CLICKED && e.getButton() == 1 && !movedOrResized) {
            int viewIndex = columnAtPoint(e.getPoint());
            if (viewIndex != -1 && table != null) {
                RowSorter<?> sorter = table.getRowSorter();
                if (sorter != null) {
                    int modelIndex = table.convertColumnIndexToModel(viewIndex);
                    sorter.toggleSortOrder(modelIndex);
                }
            }
        }
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        super.processMouseMotionEvent(e);
        if (e.getID() != MouseEvent.MOUSE_DRAGGED || !enabled) return;
        int mouseX = e.getX();
        TableColumn rc = getResizingColumn();
        TableColumn dc = getDraggedColumn();
        if (rc != null) {
            movedOrResized = true;
            rc.setWidth(mouseX - mouseXOffset);
        } else if (dc != null) {
            TableColumnModel cm = getColumnModel();
            int distance = mouseX - mouseXOffset;
            if (Math.abs(distance) > 3) movedOrResized = true;
            int direction = (distance < 0) ? -1 : 1;
            int columnIndex = viewIndexForColumn(dc);
            int newColumnIndex = columnIndex + direction;
            if (0 <= newColumnIndex && newColumnIndex < cm.getColumnCount()) {
                int width = cm.getColumn(newColumnIndex).getWidth();
                if (Math.abs(distance) > (width / 2)) {
                    mouseXOffset = mouseXOffset + direction * width;
                    setDraggedDistance(distance - direction * width);
                    cm.moveColumn(columnIndex, newColumnIndex);
                    return;
                }
            }
            setDraggedDistance(distance);
        }
    }
    private int viewIndexForColumn(TableColumn aColumn) {
        TableColumnModel cm = getColumnModel();
        for (int column = 0; column < cm.getColumnCount(); column++) if (cm.getColumn(column) == aColumn) return column;
        return -1;
    }
    // ---- peinture ----
    protected void paintComponent(Graphics g) {
        g.setColor(getBackground());
        g.fillRect(0, 0, width, height);
        if (columnModel.getColumnCount() <= 0) return;
        Rectangle clip = g.getClipBounds();
        int cMin = clip == null ? 0 : columnAtPoint(new Point(clip.x, 0));
        int cMax = clip == null ? columnModel.getColumnCount() - 1 : columnAtPoint(new Point(Math.max(clip.x, clip.x + clip.width - 1), 0));
        if (cMin == -1) cMin = 0;
        if (cMax == -1) cMax = columnModel.getColumnCount() - 1;
        TableColumn dragged = getDraggedColumn();
        int columnWidth;
        Rectangle cellRect = getHeaderRect(cMin);
        for (int column = cMin; column <= cMax; column++) {
            TableColumn aColumn = columnModel.getColumn(column);
            columnWidth = aColumn.getWidth();
            cellRect.width = columnWidth;
            if (aColumn != dragged) paintCell(g, cellRect, column);
            cellRect.x += columnWidth;
        }
        if (dragged != null) {
            int draggedColumnIndex = viewIndexForColumn(dragged);
            Rectangle draggedCellRect = getHeaderRect(draggedColumnIndex);
            g.setColor(new Color(214, 223, 232));
            g.fillRect(draggedCellRect.x, 0, draggedCellRect.width, height);
            draggedCellRect.x += getDraggedDistance();
            paintCell(g, draggedCellRect, draggedColumnIndex);
        }
    }
    private void paintCell(Graphics g, Rectangle cellRect, int columnIndex) {
        TableColumn aColumn = columnModel.getColumn(columnIndex);
        Component c = renderer(aColumn, columnIndex);
        JComponent.paintCell(g, c, this, cellRect.x, cellRect.y, cellRect.width, cellRect.height);
    }
    static class HeaderRenderer extends DefaultTableCellRenderer implements javax.swing.plaf.UIResource {
        private int sortDir;
        HeaderRenderer() { setHorizontalAlignment(LEADING); setBorder(new EmptyBorder(4, 5, 4, 5)); }
        public Component getTableCellRendererComponent(JTable table, Object value, boolean isSelected, boolean hasFocus, int row, int column) {
            sortDir = 0;
            if (table != null) {
                JTableHeader header = table.getTableHeader();
                if (header != null) { setForeground(header.getForeground()); setBackground(header.getBackground()); setFont(header.getFont()); }
                RowSorter<?> sorter = table.getRowSorter();
                if (sorter != null && column >= 0 && column < table.getColumnCount()) {
                    int mc = table.convertColumnIndexToModel(column);
                    java.util.List<? extends RowSorter.SortKey> keys = sorter.getSortKeys();
                    if (keys.size() > 0 && keys.get(0).getColumn() == mc) {
                        SortOrder so = keys.get(0).getSortOrder();
                        sortDir = so == SortOrder.ASCENDING ? 1 : so == SortOrder.DESCENDING ? -1 : 0;
                    }
                }
            }
            setText(value == null ? "" : value.toString());
            setIcon(null);
            return this;
        }
        public Dimension getPreferredSize() {
            Dimension d = super.getPreferredSize();
            return sortDir != 0 ? new Dimension(d.width + 12, d.height) : d;
        }
        protected void paintComponent(Graphics g) {
            Color border = new Color(122, 138, 153);
            int w = getWidth(), h = getHeight();
            for (int j = 0; j < h; j++) {
                double t = h <= 1 ? 0 : (double) j / (h - 1);
                int r = 246 - (int) (34 * t), gg = 249 - (int) (24 * t), b = 252 - (int) (14 * t);
                g.setColor(new Color(r, gg, b));
                g.drawLine(0, j, w - 1, j);
            }
            g.setColor(border);
            g.drawLine(w - 1, 0, w - 1, h - 1);
            g.drawLine(0, h - 1, w - 1, h - 1);
            g.setColor(Color.WHITE);
            g.drawLine(0, 0, w - 2, 0);
            g.drawLine(0, 0, 0, h - 2);
            Border b = getBorder();
            Insets in = b != null ? b.getBorderInsets(this) : new Insets(0, 0, 0, 0);
            FontMetrics fm = g.getFontMetrics(getFont());
            g.setFont(getFont());
            g.setColor(new Color(51, 51, 51));
            String t = getText();
            int tw = fm.stringWidth(t);
            int x = in.left;
            int hAlign = getHorizontalAlignment();
            int avail = w - in.left - in.right - (sortDir != 0 ? 12 : 0);
            if (hAlign == CENTER) x += (avail - tw) / 2; else if (hAlign == RIGHT) x += avail - tw;
            g.drawString(t, x, (h - fm.getHeight()) / 2 + fm.getAscent());
            if (sortDir != 0) {
                int cx = w - 12, cy = h / 2;
                g.setColor(new Color(51, 51, 51));
                if (sortDir > 0) g.fillPolygon(new int[] { cx - 4, cx + 4, cx }, new int[] { cy + 2, cy + 2, cy - 3 }, 3);
                else g.fillPolygon(new int[] { cx - 4, cx + 4, cx }, new int[] { cy - 2, cy - 2, cy + 3 }, 3);
            }
        }
    }
}
