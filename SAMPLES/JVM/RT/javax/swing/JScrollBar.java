package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.ArrayList;
import javax.swing.event.*;
public class JScrollBar extends JComponent implements Adjustable {
    private BoundedRangeModel model;
    private int orientation;
    private int unitIncrement = 1;
    private int blockIncrement = 10;
    private final ArrayList<AdjustmentListener> adjListeners = new ArrayList<>();
    private ChangeListener modelListener;
    static final int THICK = 15;
    static final int MINTHUMB = 17;
    private int dragOff = -1, hot = 0;
    private Timer repeat;
    private int repeatKind, repeatPos;
    public JScrollBar() { this(VERTICAL); }
    public JScrollBar(int orientation) { this(orientation, 0, 10, 0, 100); }
    public JScrollBar(int orientation, int value, int extent, int min, int max) {
        if (orientation != HORIZONTAL && orientation != VERTICAL) throw new IllegalArgumentException("orientation must be one of: VERTICAL, HORIZONTAL");
        this.orientation = orientation;
        opaque = true;
        setModel(new DefaultBoundedRangeModel(value, extent, min, max));
    }
    public void setModel(BoundedRangeModel m) {
        if (model != null && modelListener != null) model.removeChangeListener(modelListener);
        model = m;
        if (modelListener == null) {
            modelListener = new ChangeListener() {
                public void stateChanged(ChangeEvent e) {
                    fireAdjustmentValueChanged(AdjustmentEvent.ADJUSTMENT_VALUE_CHANGED, AdjustmentEvent.TRACK, model.getValue(), model.getValueIsAdjusting());
                    repaint();
                }
            };
        }
        model.addChangeListener(modelListener);
        repaint();
    }
    public BoundedRangeModel getModel() { return model; }
    public int getOrientation() { return orientation; }
    public void setOrientation(int o) { orientation = o; invalidate(); repaint(); }
    public int getValue() { return model.getValue(); }
    public void setValue(int v) { model.setValue(v); }
    public int getVisibleAmount() { return model.getExtent(); }
    public void setVisibleAmount(int e) { model.setExtent(e); }
    public int getMinimum() { return model.getMinimum(); }
    public void setMinimum(int m) { model.setMinimum(m); }
    public int getMaximum() { return model.getMaximum(); }
    public void setMaximum(int m) { model.setMaximum(m); }
    public boolean getValueIsAdjusting() { return model.getValueIsAdjusting(); }
    public void setValueIsAdjusting(boolean b) { model.setValueIsAdjusting(b); }
    public void setValues(int newValue, int newExtent, int newMin, int newMax) { model.setRangeProperties(newValue, newExtent, newMin, newMax, model.getValueIsAdjusting()); }
    public int getUnitIncrement() { return unitIncrement; }
    public int getUnitIncrement(int direction) { return unitIncrement; }
    public void setUnitIncrement(int u) { unitIncrement = u; }
    public int getBlockIncrement() { return blockIncrement; }
    public int getBlockIncrement(int direction) { return blockIncrement; }
    public void setBlockIncrement(int b) { blockIncrement = b; }
    public void addAdjustmentListener(AdjustmentListener l) { if (l != null) adjListeners.add(l); }
    public void removeAdjustmentListener(AdjustmentListener l) { adjListeners.remove(l); }
    public AdjustmentListener[] getAdjustmentListeners() { return adjListeners.toArray(new AdjustmentListener[0]); }
    protected void fireAdjustmentValueChanged(int id, int type, int value, boolean isAdjusting) {
        if (adjListeners.isEmpty()) return;
        AdjustmentEvent e = new AdjustmentEvent(this, id, type, value, isAdjusting);
        for (AdjustmentListener l : new ArrayList<>(adjListeners)) l.adjustmentValueChanged(e);
    }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        return orientation == VERTICAL ? new Dimension(THICK, 48) : new Dimension(48, THICK);
    }
    public Dimension getMinimumSize() { return orientation == VERTICAL ? new Dimension(THICK, THICK * 2 + MINTHUMB) : new Dimension(THICK * 2 + MINTHUMB, THICK); }
    boolean vertical() { return orientation == VERTICAL; }
    int len() { return vertical() ? height : width; }
    int trackLen() { return Math.max(0, len() - 2 * THICK); }
    int thumbLen() {
        int range = model.getMaximum() - model.getMinimum();
        int track = trackLen();
        if (range <= 0) return track;
        int t = (int) ((long) track * model.getExtent() / range);
        return Math.min(track, Math.max(MINTHUMB, t));
    }
    int thumbPos() {
        int span = model.getMaximum() - model.getMinimum() - model.getExtent();
        int free = trackLen() - thumbLen();
        if (span <= 0 || free <= 0) return THICK;
        return THICK + (int) ((long) free * (model.getValue() - model.getMinimum()) / span);
    }
    boolean scrollable() { return model.getMaximum() - model.getMinimum() > model.getExtent() && enabled; }
    public boolean wantsMouse() { return true; }
    public boolean focusTraversable() { return false; }
    int posOf(MouseEvent e) { return vertical() ? e.getY() : e.getX(); }
    void step(int kind) {
        int dir = (kind == 1 || kind == 3) ? 1 : -1;
        int amt = (kind <= 2) ? getUnitIncrement(dir) : getBlockIncrement(dir);
        setValue(getValue() + dir * amt);
    }
    protected void processMouseEvent(MouseEvent e) {
        int id = e.getID();
        if (id == MouseEvent.MOUSE_PRESSED) {
            if (!scrollable() || e.getButton() != 1) return;
            int p = posOf(e);
            if (p < THICK) { hot = 1; repeatKind = 2; }
            else if (p >= len() - THICK) { hot = 2; repeatKind = 1; }
            else {
                int tp = thumbPos(), tl = thumbLen();
                if (p >= tp && p < tp + tl) { dragOff = p - tp; model.setValueIsAdjusting(true); hot = 3; repaint(); return; }
                hot = 4;
                repeatKind = p < tp ? 4 : 3;
                repeatPos = p;
            }
            step(repeatKind);
            repeat = new Timer(60, new ActionListener() {
                public void actionPerformed(ActionEvent ev) {
                    if (hot == 4) {
                        int tp = thumbPos(), tl = thumbLen();
                        if (repeatPos >= tp && repeatPos < tp + tl) return;
                    }
                    step(repeatKind);
                }
            });
            repeat.setInitialDelay(300);
            repeat.start();
            repaint();
        } else if (id == MouseEvent.MOUSE_RELEASED) {
            if (repeat != null) { repeat.stop(); repeat = null; }
            if (dragOff >= 0) { dragOff = -1; model.setValueIsAdjusting(false); }
            hot = 0;
            repaint();
        }
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        if (dragOff >= 0 && e.getID() == MouseEvent.MOUSE_DRAGGED) {
            int free = trackLen() - thumbLen();
            if (free <= 0) return;
            int np = posOf(e) - dragOff - THICK;
            if (np < 0) np = 0;
            if (np > free) np = free;
            int span = model.getMaximum() - model.getMinimum() - model.getExtent();
            setValue(model.getMinimum() + (int) ((long) np * span / free));
        } else if (hot == 4 && e.getID() == MouseEvent.MOUSE_DRAGGED) repeatPos = posOf(e);
    }
    static void arrow(Graphics g, int cx, int cy, int dir) {
        int[] xs, ys;
        switch (dir) {
            case 0: xs = new int[] { cx - 3, cx + 3, cx }; ys = new int[] { cy + 2, cy + 2, cy - 2 }; break;
            case 1: xs = new int[] { cx - 3, cx + 3, cx }; ys = new int[] { cy - 2, cy - 2, cy + 2 }; break;
            case 2: xs = new int[] { cx + 2, cx + 2, cx - 2 }; ys = new int[] { cy - 3, cy + 3, cy }; break;
            default: xs = new int[] { cx - 2, cx - 2, cx + 2 }; ys = new int[] { cy - 3, cy + 3, cy }; break;
        }
        g.fillPolygon(xs, ys, 3);
    }
    protected void paintComponent(Graphics g) {
        Color border = new Color(122, 138, 153);
        g.setColor(new Color(238, 238, 238));
        g.fillRect(0, 0, width, height);
        boolean v = vertical();
        boolean on = scrollable();
        int L = len();
        g.setColor(new Color(214, 220, 227));
        if (v) g.fillRect(1, THICK, width - 2, trackLen()); else g.fillRect(THICK, 1, trackLen(), height - 2);
        // boutons fleches
        for (int k = 0; k < 2; k++) {
            int p = k == 0 ? 0 : L - THICK;
            boolean pr = hot == (k == 0 ? 1 : 2);
            int bx = v ? 0 : p, by = v ? p : 0;
            if (on) AbstractButton.gradient(g, bx + 1, by + 1, THICK - 2, THICK - 2, pr, false);
            else { g.setColor(new Color(238, 238, 238)); g.fillRect(bx + 1, by + 1, THICK - 2, THICK - 2); }
            g.setColor(on ? border : new Color(184, 184, 184));
            g.drawRect(bx, by, v ? width - 1 : THICK - 1, v ? THICK - 1 : height - 1);
            g.setColor(on ? new Color(51, 51, 51) : new Color(153, 153, 153));
            int cx = bx + (v ? width / 2 : THICK / 2), cy = by + (v ? THICK / 2 : height / 2);
            arrow(g, cx, cy, v ? k : 2 + k);
        }
        if (on) {
            int tp = thumbPos(), tl = thumbLen();
            if (v) {
                AbstractButton.gradient(g, 1, tp + 1, width - 2, tl - 2, hot == 3, false);
                g.setColor(border); g.drawRect(0, tp, width - 1, tl - 1);
                int cy = tp + tl / 2;
                g.setColor(new Color(122, 138, 153));
                for (int i = -3; i <= 3; i += 3) g.drawLine(3, cy + i, width - 4, cy + i);
            } else {
                AbstractButton.gradient(g, tp + 1, 1, tl - 2, height - 2, hot == 3, false);
                g.setColor(border); g.drawRect(tp, 0, tl - 1, height - 1);
                int cx = tp + tl / 2;
                g.setColor(new Color(122, 138, 153));
                for (int i = -3; i <= 3; i += 3) g.drawLine(cx + i, 3, cx + i, height - 4);
            }
        }
    }
}
