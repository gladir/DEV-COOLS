package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import java.util.List;
import javax.swing.event.*;
public class JList<E> extends JComponent implements Scrollable {
    public static final int VERTICAL = 0, VERTICAL_WRAP = 1, HORIZONTAL_WRAP = 2;
    private ListModel<E> dataModel;
    private ListSelectionModel selectionModel;
    private ListCellRenderer<? super E> cellRenderer;
    private int visibleRowCount = 8, fixedCellWidth = -1, fixedCellHeight = -1, layoutOrientation = VERTICAL;
    private Color selBg = new Color(184, 207, 229), selFg = new Color(51, 51, 51);
    private E prototype;
    private int[] ys = new int[1];
    private int maxCellW;
    private boolean layoutValid;
    private boolean dragEnabled;
    private final ArrayList<ListSelectionListener> listeners = new ArrayList<>();
    private final ListDataListener dataListener = new ListDataListener() {
        public void intervalAdded(ListDataEvent e) {
            int min = Math.min(e.getIndex0(), e.getIndex1()), max = Math.max(e.getIndex0(), e.getIndex1());
            selectionModel.insertIndexInterval(min, max - min + 1, true);
            changed();
        }
        public void intervalRemoved(ListDataEvent e) {
            int min = Math.min(e.getIndex0(), e.getIndex1()), max = Math.max(e.getIndex0(), e.getIndex1());
            selectionModel.removeIndexInterval(min, max);
            changed();
        }
        public void contentsChanged(ListDataEvent e) { changed(); }
    };
    private final ListSelectionListener selListener = new ListSelectionListener() {
        public void valueChanged(ListSelectionEvent e) {
            ListSelectionEvent ne = new ListSelectionEvent(JList.this, e.getFirstIndex(), e.getLastIndex(), e.getValueIsAdjusting());
            for (ListSelectionListener l : new ArrayList<>(listeners)) l.valueChanged(ne);
            repaint();
        }
    };
    public JList(ListModel<E> dataModel) {
        if (dataModel == null) throw new IllegalArgumentException("dataModel must be non null");
        opaque = true;
        background = Color.WHITE;
        foreground = new Color(51, 51, 51);
        this.dataModel = dataModel;
        selectionModel = new DefaultListSelectionModel();
        cellRenderer = (ListCellRenderer<? super E>) new DefaultListCellRenderer();
        dataModel.addListDataListener(dataListener);
        selectionModel.addListSelectionListener(selListener);
    }
    @SuppressWarnings("unchecked")
    public JList(final E[] listData) {
        this(new AbstractListModel<E>() {
            public int getSize() { return listData.length; }
            public E getElementAt(int i) { return listData[i]; }
        });
    }
    public JList(final Vector<? extends E> listData) {
        this(new AbstractListModel<E>() {
            public int getSize() { return listData.size(); }
            public E getElementAt(int i) { return listData.elementAt(i); }
        });
    }
    public JList() {
        this(new AbstractListModel<E>() {
            public int getSize() { return 0; }
            public E getElementAt(int i) { throw new IndexOutOfBoundsException("No elements"); }
        });
    }
    void changed() { layoutValid = false; revalidate(); repaint(); }
    public ListModel<E> getModel() { return dataModel; }
    public void setModel(ListModel<E> model) {
        if (model == null) throw new IllegalArgumentException("model must be non null");
        ListModel<E> old = dataModel;
        old.removeListDataListener(dataListener);
        dataModel = model;
        model.addListDataListener(dataListener);
        firePropertyChange("model", old, model);
        clearSelection();
        changed();
    }
    public void setListData(final E[] listData) {
        setModel(new AbstractListModel<E>() {
            public int getSize() { return listData.length; }
            public E getElementAt(int i) { return listData[i]; }
        });
    }
    public void setListData(final Vector<? extends E> listData) {
        setModel(new AbstractListModel<E>() {
            public int getSize() { return listData.size(); }
            public E getElementAt(int i) { return listData.elementAt(i); }
        });
    }
    public ListSelectionModel getSelectionModel() { return selectionModel; }
    public void setSelectionModel(ListSelectionModel m) {
        if (m == null) throw new IllegalArgumentException("selectionModel must be non null");
        ListSelectionModel old = selectionModel;
        old.removeListSelectionListener(selListener);
        selectionModel = m;
        m.addListSelectionListener(selListener);
        firePropertyChange("selectionModel", old, m);
        repaint();
    }
    public ListCellRenderer<? super E> getCellRenderer() { return cellRenderer; }
    public void setCellRenderer(ListCellRenderer<? super E> r) { ListCellRenderer<? super E> old = cellRenderer; cellRenderer = r; changed(); firePropertyChange("cellRenderer", old, r); }
    public Color getSelectionBackground() { return selBg; }
    public void setSelectionBackground(Color c) { selBg = c; repaint(); }
    public Color getSelectionForeground() { return selFg; }
    public void setSelectionForeground(Color c) { selFg = c; repaint(); }
    public int getVisibleRowCount() { return visibleRowCount; }
    public void setVisibleRowCount(int n) { visibleRowCount = Math.max(0, n); invalidate(); }
    public int getLayoutOrientation() { return layoutOrientation; }
    public void setLayoutOrientation(int o) { layoutOrientation = o; }
    public int getFixedCellWidth() { return fixedCellWidth; }
    public void setFixedCellWidth(int w) { fixedCellWidth = w; changed(); }
    public int getFixedCellHeight() { return fixedCellHeight; }
    public void setFixedCellHeight(int h) { fixedCellHeight = h; changed(); }
    public E getPrototypeCellValue() { return prototype; }
    public void setPrototypeCellValue(E v) { prototype = v; changed(); }
    public void setDragEnabled(boolean b) { dragEnabled = b; }
    public boolean getDragEnabled() { return dragEnabled; }
    public void setSelectionMode(int m) { selectionModel.setSelectionMode(m); }
    public int getSelectionMode() { return selectionModel.getSelectionMode(); }
    public int getAnchorSelectionIndex() { return selectionModel.getAnchorSelectionIndex(); }
    public int getLeadSelectionIndex() { return selectionModel.getLeadSelectionIndex(); }
    public int getMinSelectionIndex() { return selectionModel.getMinSelectionIndex(); }
    public int getMaxSelectionIndex() { return selectionModel.getMaxSelectionIndex(); }
    public boolean isSelectedIndex(int i) { return selectionModel.isSelectedIndex(i); }
    public boolean isSelectionEmpty() { return selectionModel.isSelectionEmpty(); }
    public void clearSelection() { selectionModel.clearSelection(); }
    public void setSelectionInterval(int a, int b) { selectionModel.setSelectionInterval(a, b); }
    public void addSelectionInterval(int a, int b) { selectionModel.addSelectionInterval(a, b); }
    public void removeSelectionInterval(int a, int b) { selectionModel.removeSelectionInterval(a, b); }
    public void setValueIsAdjusting(boolean b) { selectionModel.setValueIsAdjusting(b); }
    public boolean getValueIsAdjusting() { return selectionModel.getValueIsAdjusting(); }
    public int[] getSelectedIndices() {
        int iMin = selectionModel.getMinSelectionIndex(), iMax = selectionModel.getMaxSelectionIndex();
        if (iMin < 0 || iMax < 0) return new int[0];
        int[] rvTmp = new int[1 + (iMax - iMin)];
        int n = 0;
        for (int i = iMin; i <= iMax; i++) if (selectionModel.isSelectedIndex(i)) rvTmp[n++] = i;
        return Arrays.copyOf(rvTmp, n);
    }
    public void setSelectedIndex(int index) {
        if (index >= dataModel.getSize()) return;
        if (index < 0) selectionModel.clearSelection(); else selectionModel.setSelectionInterval(index, index);
    }
    public void setSelectedIndices(int[] indices) {
        ListSelectionModel sm = selectionModel;
        sm.clearSelection();
        int size = dataModel.getSize();
        for (int i : indices) if (i < size) sm.addSelectionInterval(i, i);
    }
    public int getSelectedIndex() { return getMinSelectionIndex(); }
    public E getSelectedValue() { int i = getMinSelectionIndex(); return (i == -1) ? null : dataModel.getElementAt(i); }
    public List<E> getSelectedValuesList() {
        ArrayList<E> l = new ArrayList<>();
        for (int i : getSelectedIndices()) l.add(dataModel.getElementAt(i));
        return l;
    }
    public Object[] getSelectedValues() { return getSelectedValuesList().toArray(); }
    public void setSelectedValue(Object anObject, boolean shouldScroll) {
        if (anObject == null) setSelectedIndex(-1);
        else if (!anObject.equals(getSelectedValue())) {
            int n = dataModel.getSize();
            for (int i = 0; i < n; i++) {
                if (anObject.equals(dataModel.getElementAt(i))) {
                    setSelectedIndex(i);
                    if (shouldScroll) ensureIndexIsVisible(i);
                    repaint();
                    return;
                }
            }
            setSelectedIndex(-1);
        }
        repaint();
    }
    public void addListSelectionListener(ListSelectionListener l) { listeners.add(l); }
    public void removeListSelectionListener(ListSelectionListener l) { listeners.remove(l); }
    public ListSelectionListener[] getListSelectionListeners() { return listeners.toArray(new ListSelectionListener[0]); }
    // ---- geometrie ----
    Component renderer(int i, boolean sel, boolean focus) {
        E v = dataModel.getElementAt(i);
        Component c = cellRenderer.getListCellRendererComponent(this, v, i, sel, focus);
        JComponent.attach(c, this);
        return c;
    }
    void ensureLayout() {
        if (layoutValid) return;
        int n = dataModel.getSize();
        ys = new int[n + 1];
        maxCellW = 0;
        if (prototype != null || fixedCellHeight > 0) {
            int h = fixedCellHeight;
            if (prototype != null) {
                Component c = cellRenderer.getListCellRendererComponent(this, prototype, 0, false, false);
                JComponent.attach(c, this);
                Dimension d = c.getPreferredSize();
                maxCellW = d.width;
                if (h <= 0) h = d.height;
            }
            for (int i = 0; i < n; i++) ys[i + 1] = (i + 1) * h;
            if (prototype == null) {
                for (int i = 0; i < n; i++) maxCellW = Math.max(maxCellW, renderer(i, false, false).getPreferredSize().width);
            }
        } else {
            for (int i = 0; i < n; i++) {
                Dimension d = renderer(i, false, false).getPreferredSize();
                maxCellW = Math.max(maxCellW, d.width);
                ys[i + 1] = ys[i] + d.height;
            }
        }
        if (fixedCellWidth > 0) maxCellW = fixedCellWidth;
        layoutValid = true;
    }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        ensureLayout();
        Insets in = getInsets();
        return new Dimension(maxCellW + in.left + in.right, ys[dataModel.getSize()] + in.top + in.bottom);
    }
    public Rectangle getCellBounds(int i0, int i1) {
        ensureLayout();
        int n = dataModel.getSize();
        int lo = Math.min(i0, i1), hi = Math.max(i0, i1);
        if (lo < 0 || hi >= n) {
            if (lo >= n || hi < 0) return null;
            lo = Math.max(lo, 0); hi = Math.min(hi, n - 1);
        }
        Insets in = getInsets();
        return new Rectangle(in.left, in.top + ys[lo], width - in.left - in.right, ys[hi + 1] - ys[lo]);
    }
    public Point indexToLocation(int index) { Rectangle r = getCellBounds(index, index); return r == null ? null : new Point(r.x, r.y); }
    public int locationToIndex(Point p) {
        ensureLayout();
        int n = dataModel.getSize();
        if (n == 0) return -1;
        int y = p.y - getInsets().top;
        if (y < 0) return 0;
        if (y >= ys[n]) return n - 1;
        int lo = 0, hi = n - 1;
        while (lo < hi) {
            int mid = (lo + hi + 1) >>> 1;
            if (ys[mid] <= y) lo = mid; else hi = mid - 1;
        }
        return lo;
    }
    public int getFirstVisibleIndex() {
        Rectangle r = getVisibleRect();
        if (r.height == 0 && r.width == 0) return -1;
        return dataModel.getSize() == 0 ? -1 : locationToIndex(new Point(r.x, r.y));
    }
    public int getLastVisibleIndex() {
        Rectangle r = getVisibleRect();
        if (dataModel.getSize() == 0 || (r.height == 0 && r.width == 0)) return -1;
        int i = locationToIndex(new Point(r.x, r.y + r.height - 1));
        Rectangle b = getCellBounds(i, i);
        if (b != null && b.y >= r.y + r.height && i > 0) i--;
        return i;
    }
    public void ensureIndexIsVisible(int index) {
        Rectangle r = getCellBounds(index, index);
        if (r != null) scrollRectToVisible(r);
    }
    // ---- Scrollable ----
    public Dimension getPreferredScrollableViewportSize() {
        if (getLayoutOrientation() != VERTICAL) return getPreferredSize();
        Insets in = getInsets();
        int dx = in.left + in.right, dy = in.top + in.bottom;
        int visibleRows = visibleRowCount;
        int w, h;
        if (fixedCellWidth > 0) w = fixedCellWidth + dx;
        else if (dataModel.getSize() > 0) w = getPreferredSize().width;
        else w = 256;
        if (fixedCellHeight > 0) h = fixedCellHeight * visibleRows + dy;
        else if (dataModel.getSize() > 0) {
            Rectangle r0 = getCellBounds(0, 0);
            h = r0.height * visibleRows + dy;
        } else h = 16 * visibleRows + dy;
        return new Dimension(w, h);
    }
    public int getScrollableUnitIncrement(Rectangle visibleRect, int orientation, int direction) {
        if (orientation == SwingConstants.VERTICAL) {
            int row = locationToIndex(new Point(visibleRect.x, visibleRect.y));
            if (row == -1) return 0;
            Rectangle r = getCellBounds(row, row);
            if (direction > 0) return r.y + r.height - visibleRect.y;
            if (r.y < visibleRect.y) return visibleRect.y - r.y;
            if (row > 0) return getCellBounds(row - 1, row - 1).height;
            return 0;
        }
        return 8;
    }
    public int getScrollableBlockIncrement(Rectangle visibleRect, int orientation, int direction) {
        if (orientation == SwingConstants.VERTICAL) {
            int inc = visibleRect.height;
            if (direction > 0) {
                int last = locationToIndex(new Point(visibleRect.x, visibleRect.y + visibleRect.height - 1));
                if (last != -1) {
                    Rectangle lr = getCellBounds(last, last);
                    inc = lr.y - visibleRect.y;
                    if (inc == 0 && last < dataModel.getSize() - 1) inc = lr.height;
                    if (inc == 0) inc = visibleRect.height;
                }
            } else {
                int first = locationToIndex(new Point(visibleRect.x, visibleRect.y));
                if (first != -1) {
                    Rectangle fr = getCellBounds(first, first);
                    inc = visibleRect.height;
                    if (fr.y != visibleRect.y) inc = visibleRect.y - (fr.y + fr.height - visibleRect.height) ;
                    if (inc <= 0) inc = visibleRect.height;
                }
            }
            return inc;
        }
        return visibleRect.width;
    }
    public boolean getScrollableTracksViewportWidth() {
        if (getParent() instanceof JViewport) return ((JViewport) getParent()).getWidth() > getPreferredSize().width;
        return false;
    }
    public boolean getScrollableTracksViewportHeight() { return false; }
    // ---- evenements ----
    public boolean focusTraversable() { return true; }
    public boolean wantsMouse() { return true; }
    public boolean wantsKeys() { return true; }
    private int dragAnchor = -1;
    private boolean pointInCell(int idx, MouseEvent e) {
        Rectangle b = getCellBounds(idx, idx);
        return b != null && e.getY() >= b.y && e.getY() < b.y + b.height;
    }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (!enabled) return;
        if (e.getID() == MouseEvent.MOUSE_PRESSED && e.getButton() == 1) {
            int idx = locationToIndex(e.getPoint());
            if (idx >= 0 && pointInCell(idx, e)) {
                selectionModel.setValueIsAdjusting(true);
                if (e.isControlDown() && getSelectionMode() != ListSelectionModel.SINGLE_SELECTION) {
                    if (selectionModel.isSelectedIndex(idx)) selectionModel.removeSelectionInterval(idx, idx);
                    else selectionModel.addSelectionInterval(idx, idx);
                } else if (e.isShiftDown() && getSelectionMode() != ListSelectionModel.SINGLE_SELECTION && selectionModel.getAnchorSelectionIndex() >= 0) {
                    selectionModel.setSelectionInterval(selectionModel.getAnchorSelectionIndex(), idx);
                } else selectionModel.setSelectionInterval(idx, idx);
                dragAnchor = selectionModel.getAnchorSelectionIndex();
            } else dragAnchor = -1;
            repaint();
        } else if (e.getID() == MouseEvent.MOUSE_RELEASED) {
            dragAnchor = -1;
            selectionModel.setValueIsAdjusting(false);
        }
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        super.processMouseMotionEvent(e);
        if (e.getID() == MouseEvent.MOUSE_DRAGGED && dragAnchor >= 0 && enabled) {
            int idx = locationToIndex(e.getPoint());
            if (idx >= 0) {
                if (getSelectionMode() == ListSelectionModel.SINGLE_SELECTION) selectionModel.setSelectionInterval(idx, idx);
                else selectionModel.setSelectionInterval(dragAnchor, idx);
                ensureIndexIsVisible(idx);
            }
        }
    }
    protected void processKeyEvent(KeyEvent e) {
        super.processKeyEvent(e);
        if (e.isConsumed() || e.getID() != KeyEvent.KEY_PRESSED || !enabled) return;
        int n = dataModel.getSize();
        if (n == 0) return;
        int lead = selectionModel.getLeadSelectionIndex();
        if (lead < 0) lead = getMinSelectionIndex();
        int ni = lead;
        switch (e.getKeyCode()) {
            case KeyEvent.VK_DOWN: ni = lead < 0 ? 0 : Math.min(n - 1, lead + 1); break;
            case KeyEvent.VK_UP: ni = lead < 0 ? 0 : Math.max(0, lead - 1); break;
            case KeyEvent.VK_HOME: ni = 0; break;
            case KeyEvent.VK_END: ni = n - 1; break;
            case KeyEvent.VK_PAGE_DOWN: ni = Math.min(n - 1, Math.max(lead, getLastVisibleIndex()) + (lead >= getLastVisibleIndex() ? Math.max(1, getLastVisibleIndex() - getFirstVisibleIndex()) : 0)); break;
            case KeyEvent.VK_PAGE_UP: ni = Math.max(0, Math.min(lead, getFirstVisibleIndex()) - (lead <= getFirstVisibleIndex() ? Math.max(1, getLastVisibleIndex() - getFirstVisibleIndex()) : 0)); break;
            case KeyEvent.VK_A:
                if (e.isControlDown() && getSelectionMode() == ListSelectionModel.MULTIPLE_INTERVAL_SELECTION) { selectionModel.setSelectionInterval(0, n - 1); }
                return;
            default: return;
        }
        selectionModel.setSelectionInterval(ni, ni);
        ensureIndexIsVisible(ni);
        e.consume();
    }
    protected void paintComponent(Graphics g) {
        g.setColor(getBackground());
        g.fillRect(0, 0, width, height);
        ensureLayout();
        int n = dataModel.getSize();
        if (n == 0) return;
        Rectangle clip = g.getClipBounds();
        Insets in = getInsets();
        int y0 = clip == null ? 0 : clip.y, y1 = clip == null ? height : clip.y + clip.height;
        int first = locationToIndex(new Point(0, y0));
        boolean focus = isFocusOwner();
        int lead = selectionModel.getLeadSelectionIndex();
        for (int i = first; i < n; i++) {
            int y = in.top + ys[i];
            if (y >= y1) break;
            Component c = renderer(i, selectionModel.isSelectedIndex(i), focus && i == lead);
            JComponent.paintCell(g, c, this, in.left, y, width - in.left - in.right, ys[i + 1] - ys[i]);
        }
    }
}
