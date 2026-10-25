package javax.swing;
import java.awt.*;
import java.awt.event.*;
import javax.swing.border.*;
import javax.swing.event.*;
public class JScrollPane extends JComponent implements ScrollPaneConstants {
    protected JViewport viewport;
    protected JScrollBar verticalScrollBar, horizontalScrollBar;
    protected JViewport rowHeader, columnHeader;
    protected Component lowerLeft, lowerRight, upperLeft, upperRight;
    protected int verticalScrollBarPolicy = VERTICAL_SCROLLBAR_AS_NEEDED;
    protected int horizontalScrollBarPolicy = HORIZONTAL_SCROLLBAR_AS_NEEDED;
    private Border viewportBorder;
    private boolean syncing;
    private final AdjustmentListener barListener = new AdjustmentListener() {
        public void adjustmentValueChanged(AdjustmentEvent e) {
            if (syncing || viewport == null) return;
            viewport.setViewPosition(new Point(horizontalScrollBar.getValue(), verticalScrollBar.getValue()));
        }
    };
    private final ChangeListener vpListener = new ChangeListener() {
        public void stateChanged(ChangeEvent e) { syncBars(); }
    };
    class ScrollBar extends JScrollBar {
        ScrollBar(int orientation) { super(orientation); }
        public int getUnitIncrement(int direction) {
            JViewport vp = getViewport();
            if (vp == null || !(vp.getView() instanceof Scrollable)) return super.getUnitIncrement(direction);
            return ((Scrollable) vp.getView()).getScrollableUnitIncrement(vp.getViewRect(), getOrientation(), direction);
        }
        public int getBlockIncrement(int direction) {
            JViewport vp = getViewport();
            if (vp == null) return super.getBlockIncrement(direction);
            if (vp.getView() instanceof Scrollable) return ((Scrollable) vp.getView()).getScrollableBlockIncrement(vp.getViewRect(), getOrientation(), direction);
            return getOrientation() == VERTICAL ? vp.getExtentSize().height : vp.getExtentSize().width;
        }
    }
    public JScrollPane() { this(null, VERTICAL_SCROLLBAR_AS_NEEDED, HORIZONTAL_SCROLLBAR_AS_NEEDED); }
    public JScrollPane(Component view) { this(view, VERTICAL_SCROLLBAR_AS_NEEDED, HORIZONTAL_SCROLLBAR_AS_NEEDED); }
    public JScrollPane(int vsbPolicy, int hsbPolicy) { this(null, vsbPolicy, hsbPolicy); }
    public JScrollPane(Component view, int vsbPolicy, int hsbPolicy) {
        opaque = true;
        border = new LineBorder(new Color(122, 138, 153));
        setVerticalScrollBarPolicy(vsbPolicy);
        setHorizontalScrollBarPolicy(hsbPolicy);
        setViewport(new JViewport());
        setVerticalScrollBar(new ScrollBar(JScrollBar.VERTICAL));
        setHorizontalScrollBar(new ScrollBar(JScrollBar.HORIZONTAL));
        if (view != null) setViewportView(view);
    }
    public JViewport getViewport() { return viewport; }
    public void setViewport(JViewport vp) {
        JViewport old = viewport;
        if (old != null) { old.removeChangeListener(vpListener); remove(old); }
        viewport = vp;
        if (vp != null) { add(vp); vp.addChangeListener(vpListener); }
        invalidate(); repaint();
        firePropertyChange("viewport", old, vp);
    }
    public void setViewportView(Component view) {
        if (view == null) { if (viewport != null) viewport.setView(null); return; }
        Component old = viewport == null ? null : viewport.getView();
        if (old instanceof JTable && old != view) ((JTable) old).unconfigureEnclosingScrollPane(this);
        if (viewport == null) setViewport(new JViewport());
        viewport.setView(view);
        if (view instanceof JTable) ((JTable) view).configureEnclosingScrollPane(this);
        revalidate();
    }
    public JScrollBar getVerticalScrollBar() { return verticalScrollBar; }
    public JScrollBar getHorizontalScrollBar() { return horizontalScrollBar; }
    public JScrollBar createVerticalScrollBar() { return new ScrollBar(JScrollBar.VERTICAL); }
    public JScrollBar createHorizontalScrollBar() { return new ScrollBar(JScrollBar.HORIZONTAL); }
    public void setVerticalScrollBar(JScrollBar sb) {
        JScrollBar old = verticalScrollBar;
        if (old != null) { old.removeAdjustmentListener(barListener); remove(old); }
        verticalScrollBar = sb;
        if (sb != null) { add(sb); sb.addAdjustmentListener(barListener); }
        invalidate(); repaint();
        firePropertyChange("verticalScrollBar", old, sb);
    }
    public void setHorizontalScrollBar(JScrollBar sb) {
        JScrollBar old = horizontalScrollBar;
        if (old != null) { old.removeAdjustmentListener(barListener); remove(old); }
        horizontalScrollBar = sb;
        if (sb != null) { add(sb); sb.addAdjustmentListener(barListener); }
        invalidate(); repaint();
        firePropertyChange("horizontalScrollBar", old, sb);
    }
    public int getVerticalScrollBarPolicy() { return verticalScrollBarPolicy; }
    public void setVerticalScrollBarPolicy(int policy) {
        switch (policy) {
            case VERTICAL_SCROLLBAR_AS_NEEDED: case VERTICAL_SCROLLBAR_NEVER: case VERTICAL_SCROLLBAR_ALWAYS: break;
            default: throw new IllegalArgumentException("invalid verticalScrollBarPolicy");
        }
        int old = verticalScrollBarPolicy;
        verticalScrollBarPolicy = policy;
        firePropertyChange("verticalScrollBarPolicy", old, policy);
        revalidate();
    }
    public int getHorizontalScrollBarPolicy() { return horizontalScrollBarPolicy; }
    public void setHorizontalScrollBarPolicy(int policy) {
        switch (policy) {
            case HORIZONTAL_SCROLLBAR_AS_NEEDED: case HORIZONTAL_SCROLLBAR_NEVER: case HORIZONTAL_SCROLLBAR_ALWAYS: break;
            default: throw new IllegalArgumentException("invalid horizontalScrollBarPolicy");
        }
        int old = horizontalScrollBarPolicy;
        horizontalScrollBarPolicy = policy;
        firePropertyChange("horizontalScrollBarPolicy", old, policy);
        revalidate();
    }
    public Border getViewportBorder() { return viewportBorder; }
    public void setViewportBorder(Border b) { viewportBorder = b; repaint(); }
    public JViewport getRowHeader() { return rowHeader; }
    public void setRowHeader(JViewport h) { if (rowHeader != null) remove(rowHeader); rowHeader = h; if (h != null) add(h); revalidate(); }
    public void setRowHeaderView(Component v) { if (rowHeader == null) setRowHeader(new JViewport()); rowHeader.setView(v); revalidate(); }
    public JViewport getColumnHeader() { return columnHeader; }
    public void setColumnHeader(JViewport h) { if (columnHeader != null) remove(columnHeader); columnHeader = h; if (h != null) add(h); revalidate(); }
    public void setColumnHeaderView(Component v) {
        if (v == null) { if (columnHeader != null) { remove(columnHeader); columnHeader = null; revalidate(); } return; }
        if (columnHeader == null) setColumnHeader(new JViewport());
        columnHeader.setView(v);
        revalidate();
    }
    public Component getCorner(String key) {
        if (key.equals(LOWER_LEFT_CORNER)) return lowerLeft;
        if (key.equals(LOWER_RIGHT_CORNER)) return lowerRight;
        if (key.equals(UPPER_LEFT_CORNER)) return upperLeft;
        if (key.equals(UPPER_RIGHT_CORNER)) return upperRight;
        return null;
    }
    public void setCorner(String key, Component c) {
        Component old = getCorner(key);
        if (old != null) remove(old);
        if (key.equals(LOWER_LEFT_CORNER)) lowerLeft = c;
        else if (key.equals(LOWER_RIGHT_CORNER)) lowerRight = c;
        else if (key.equals(UPPER_LEFT_CORNER)) upperLeft = c;
        else if (key.equals(UPPER_RIGHT_CORNER)) upperRight = c;
        else throw new IllegalArgumentException("invalid corner key");
        if (c != null) add(c);
        revalidate();
    }
    public boolean isWheelScrollingEnabled() { return true; }
    public void setWheelScrollingEnabled(boolean b) { }
    void syncBars() {
        if (syncing || viewport == null) return;
        syncing = true;
        try {
            Point p = viewport.getViewPosition();
            Dimension vs = viewport.getViewSize();
            if (verticalScrollBar != null) verticalScrollBar.setValues(p.y, viewport.getHeight(), 0, vs.height);
            if (horizontalScrollBar != null) horizontalScrollBar.setValues(p.x, viewport.getWidth(), 0, vs.width);
            if (columnHeader != null) columnHeader.setViewPosition(new Point(p.x, 0));
            if (rowHeader != null) rowHeader.setViewPosition(new Point(0, p.y));
        } finally { syncing = false; }
        repaint();
    }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        Insets in = getInsets();
        int pw = in.left + in.right, ph = in.top + in.bottom;
        Dimension ext = null, vp = null;
        Component view = null;
        if (viewport != null) {
            ext = viewport.getPreferredSize();
            view = viewport.getView();
            if (view != null) vp = view.getPreferredSize();
        }
        if (ext != null) { pw += ext.width; ph += ext.height; }
        if (rowHeader != null && rowHeader.isVisible()) pw += rowHeader.getPreferredSize().width;
        if (columnHeader != null && columnHeader.isVisible()) ph += columnHeader.getPreferredSize().height;
        if (verticalScrollBar != null && verticalScrollBarPolicy != VERTICAL_SCROLLBAR_NEVER) {
            if (verticalScrollBarPolicy == VERTICAL_SCROLLBAR_ALWAYS) pw += JScrollBar.THICK;
            else if (vp != null && ext != null) {
                boolean can = true;
                if (view instanceof Scrollable) can = !((Scrollable) view).getScrollableTracksViewportHeight();
                if (can && vp.height > ext.height) pw += JScrollBar.THICK;
            }
        }
        if (horizontalScrollBar != null && horizontalScrollBarPolicy != HORIZONTAL_SCROLLBAR_NEVER) {
            if (horizontalScrollBarPolicy == HORIZONTAL_SCROLLBAR_ALWAYS) ph += JScrollBar.THICK;
            else if (vp != null && ext != null) {
                boolean can = true;
                if (view instanceof Scrollable) can = !((Scrollable) view).getScrollableTracksViewportWidth();
                if (can && vp.width > ext.width) ph += JScrollBar.THICK;
            }
        }
        return new Dimension(pw, ph);
    }
    public Dimension getMinimumSize() {
        if (minSize != null) return new Dimension(minSize);
        Insets in = getInsets();
        int w = in.left + in.right + 4, h = in.top + in.bottom + 4;
        if (verticalScrollBar != null && verticalScrollBarPolicy != VERTICAL_SCROLLBAR_NEVER) w += JScrollBar.THICK;
        if (horizontalScrollBar != null && horizontalScrollBarPolicy != HORIZONTAL_SCROLLBAR_NEVER) h += JScrollBar.THICK;
        return new Dimension(w, h);
    }
    public void doLayout() {
        if (viewport == null) return;
        Insets in = getInsets();
        int ax = in.left, ay = in.top, aw = Math.max(0, width - in.left - in.right), ah = Math.max(0, height - in.top - in.bottom);
        int rhw = 0, chh = 0;
        if (rowHeader != null && rowHeader.isVisible()) rhw = Math.min(aw, rowHeader.getPreferredSize().width);
        if (columnHeader != null && columnHeader.isVisible()) chh = Math.min(ah, columnHeader.getPreferredSize().height);
        int headX = ax + rhw, headY = ay + chh;
        int vw = aw - rhw, vh = ah - chh;
        Component view = viewport.getView();
        Dimension pref = view == null ? new Dimension(0, 0) : view.getPreferredSize();
        Scrollable sc = view instanceof Scrollable ? (Scrollable) view : null;
        boolean tw = sc != null && sc.getScrollableTracksViewportWidth();
        boolean th = sc != null && sc.getScrollableTracksViewportHeight();
        int bw = JScrollBar.THICK;
        boolean vneed, hneed;
        int ew = vw, eh = vh;
        if (verticalScrollBarPolicy == VERTICAL_SCROLLBAR_ALWAYS) vneed = true;
        else if (verticalScrollBarPolicy == VERTICAL_SCROLLBAR_NEVER) vneed = false;
        else vneed = !th && pref.height > eh;
        if (vneed) ew -= bw;
        if (horizontalScrollBarPolicy == HORIZONTAL_SCROLLBAR_ALWAYS) hneed = true;
        else if (horizontalScrollBarPolicy == HORIZONTAL_SCROLLBAR_NEVER) hneed = false;
        else hneed = !tw && pref.width > ew;
        if (hneed) {
            eh -= bw;
            if (verticalScrollBarPolicy == VERTICAL_SCROLLBAR_AS_NEEDED && !vneed) {
                vneed = !th && pref.height > eh;
                if (vneed) ew -= bw;
            }
        }
        if (ew < 0) ew = 0;
        if (eh < 0) eh = 0;
        viewport.setBounds(headX, headY, ew, eh);
        if (verticalScrollBar != null) {
            verticalScrollBar.setVisible(vneed);
            if (vneed) verticalScrollBar.setBounds(headX + ew, headY, bw, eh);
        }
        if (horizontalScrollBar != null) {
            horizontalScrollBar.setVisible(hneed);
            if (hneed) horizontalScrollBar.setBounds(headX, headY + eh, ew, bw);
        }
        if (columnHeader != null) columnHeader.setBounds(headX, ay, ew, chh);
        if (rowHeader != null) rowHeader.setBounds(ax, headY, rhw, eh);
        if (upperLeft != null) { upperLeft.setVisible(rhw > 0 && chh > 0); upperLeft.setBounds(ax, ay, rhw, chh); }
        if (upperRight != null) { upperRight.setVisible(vneed && chh > 0); upperRight.setBounds(headX + ew, ay, bw, chh); }
        if (lowerLeft != null) { lowerLeft.setVisible(rhw > 0 && hneed); lowerLeft.setBounds(ax, headY + eh, rhw, bw); }
        if (lowerRight != null) { lowerRight.setVisible(vneed && hneed); lowerRight.setBounds(headX + ew, headY + eh, bw, bw); }
        viewport.doLayout();
        syncBars();
    }
    public boolean wantsMouse() { return false; }
    protected void paintComponent(Graphics g) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); }
}
