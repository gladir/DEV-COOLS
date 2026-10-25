package javax.swing;
import java.awt.*;
import java.awt.event.*;
import javax.swing.border.LineBorder;
public class JSplitPane extends JComponent {
    public static final int VERTICAL_SPLIT = 0, HORIZONTAL_SPLIT = 1;
    public static final String LEFT = "left", RIGHT = "right", TOP = "top", BOTTOM = "bottom", DIVIDER = "divider";
    public static final String ORIENTATION_PROPERTY = "orientation", CONTINUOUS_LAYOUT_PROPERTY = "continuousLayout", DIVIDER_SIZE_PROPERTY = "dividerSize",
        ONE_TOUCH_EXPANDABLE_PROPERTY = "oneTouchExpandable", LAST_DIVIDER_LOCATION_PROPERTY = "lastDividerLocation", DIVIDER_LOCATION_PROPERTY = "dividerLocation",
        RESIZE_WEIGHT_PROPERTY = "resizeWeight";
    protected int orientation;
    protected boolean continuousLayout;
    protected Component leftComponent, rightComponent;
    protected int dividerSize = 10;
    protected boolean oneTouchExpandable;
    protected int lastDividerLocation;
    private int dividerLocation = -1;
    private int curLoc = -1;
    private double resizeWeight;
    private int lastSize;
    private boolean dragging;
    private int dragOff;
    public JSplitPane() { this(HORIZONTAL_SPLIT, false, new JButton("left button"), new JButton("right button")); }
    public JSplitPane(int newOrientation) { this(newOrientation, false); }
    public JSplitPane(int newOrientation, boolean newContinuousLayout) { this(newOrientation, newContinuousLayout, null, null); }
    public JSplitPane(int newOrientation, Component newLeftComponent, Component newRightComponent) { this(newOrientation, false, newLeftComponent, newRightComponent); }
    public JSplitPane(int newOrientation, boolean newContinuousLayout, Component newLeftComponent, Component newRightComponent) {
        if (newOrientation != HORIZONTAL_SPLIT && newOrientation != VERTICAL_SPLIT) throw new IllegalArgumentException("cannot create JSplitPane, orientation must be one of JSplitPane.HORIZONTAL_SPLIT or JSplitPane.VERTICAL_SPLIT");
        orientation = newOrientation;
        continuousLayout = newContinuousLayout;
        opaque = true;
        border = new LineBorder(new Color(170, 180, 190));
        if (newLeftComponent != null) setLeftComponent(newLeftComponent);
        if (newRightComponent != null) setRightComponent(newRightComponent);
    }
    public void setOrientation(int o) {
        if (o != VERTICAL_SPLIT && o != HORIZONTAL_SPLIT) throw new IllegalArgumentException("JSplitPane: orientation must be one of JSplitPane.VERTICAL_SPLIT or JSplitPane.HORIZONTAL_SPLIT");
        int old = orientation;
        orientation = o;
        firePropertyChange(ORIENTATION_PROPERTY, old, o);
        revalidate();
    }
    public int getOrientation() { return orientation; }
    public void setDividerSize(int n) { int old = dividerSize; dividerSize = n; firePropertyChange(DIVIDER_SIZE_PROPERTY, old, n); revalidate(); }
    public int getDividerSize() { return dividerSize; }
    public void setLeftComponent(Component c) {
        if (c == null) { if (leftComponent != null) { remove(leftComponent); leftComponent = null; } }
        else add(c, JSplitPane.LEFT);
    }
    public Component getLeftComponent() { return leftComponent; }
    public void setTopComponent(Component c) { setLeftComponent(c); }
    public Component getTopComponent() { return leftComponent; }
    public void setRightComponent(Component c) {
        if (c == null) { if (rightComponent != null) { remove(rightComponent); rightComponent = null; } }
        else add(c, JSplitPane.RIGHT);
    }
    public Component getRightComponent() { return rightComponent; }
    public void setBottomComponent(Component c) { setRightComponent(c); }
    public Component getBottomComponent() { return rightComponent; }
    protected void addImpl(Component comp, Object constraints, int index) {
        if (constraints != null && !(constraints instanceof String)) throw new IllegalArgumentException("cannot add to layout: constraint must be a string (or null)");
        if (constraints == null) {
            if (getLeftComponent() == null) constraints = JSplitPane.LEFT;
            else if (getRightComponent() == null) constraints = JSplitPane.RIGHT;
        }
        if (constraints != null && (constraints.equals(JSplitPane.LEFT) || constraints.equals(JSplitPane.TOP))) {
            if (leftComponent != null && leftComponent != comp) super.remove(leftComponent);
            leftComponent = comp;
            index = -1;
        } else if (constraints != null && (constraints.equals(JSplitPane.RIGHT) || constraints.equals(JSplitPane.BOTTOM))) {
            if (rightComponent != null && rightComponent != comp) super.remove(rightComponent);
            rightComponent = comp;
            index = -1;
        }
        super.addImpl(comp, constraints, index);
        revalidate();
    }
    public void remove(Component component) {
        if (component == leftComponent) leftComponent = null;
        else if (component == rightComponent) rightComponent = null;
        super.remove(component);
        revalidate();
    }
    public void remove(int index) { remove(getComponent(index)); }
    public void removeAll() { leftComponent = rightComponent = null; super.removeAll(); revalidate(); }
    public void setOneTouchExpandable(boolean b) { boolean old = oneTouchExpandable; oneTouchExpandable = b; firePropertyChange(ONE_TOUCH_EXPANDABLE_PROPERTY, old, b); repaint(); }
    public boolean isOneTouchExpandable() { return oneTouchExpandable; }
    public void setContinuousLayout(boolean b) { boolean old = continuousLayout; continuousLayout = b; firePropertyChange(CONTINUOUS_LAYOUT_PROPERTY, old, b); }
    public boolean isContinuousLayout() { return continuousLayout; }
    public void setLastDividerLocation(int n) { int old = lastDividerLocation; lastDividerLocation = n; firePropertyChange(LAST_DIVIDER_LOCATION_PROPERTY, old, n); }
    public int getLastDividerLocation() { return lastDividerLocation; }
    public void setResizeWeight(double value) {
        if (value < 0 || value > 1) throw new IllegalArgumentException("JSplitPane weight must be between 0 and 1");
        double old = resizeWeight;
        resizeWeight = value;
        firePropertyChange(RESIZE_WEIGHT_PROPERTY, Double.valueOf(old), Double.valueOf(value));
    }
    public double getResizeWeight() { return resizeWeight; }
    private boolean hz() { return orientation == HORIZONTAL_SPLIT; }
    private int full() { return hz() ? width : height; }
    private int insLo() { Insets in = getInsets(); return hz() ? in.left : in.top; }
    private int insHi() { Insets in = getInsets(); return hz() ? in.right : in.bottom; }
    private int minOf(Component c) {
        if (c == null || !c.isVisible()) return 0;
        Dimension d = c.getMinimumSize();
        return hz() ? d.width : d.height;
    }
    private int prefOf(Component c) {
        if (c == null || !c.isVisible()) return 0;
        Dimension d = c.getPreferredSize();
        return hz() ? d.width : d.height;
    }
    public int getMinimumDividerLocation() { return insLo() + minOf(leftComponent); }
    public int getMaximumDividerLocation() { return full() - insHi() - dividerSize - minOf(rightComponent); }
    public void setDividerLocation(int location) {
        int oldValue = dividerLocation;
        dividerLocation = location;
        curLoc = location;
        firePropertyChange(DIVIDER_LOCATION_PROPERTY, oldValue, location);
        setLastDividerLocation(oldValue);
        revalidate();
        repaint();
    }
    public void setDividerLocation(double proportionalLocation) {
        if (proportionalLocation < 0.0 || proportionalLocation > 1.0) throw new IllegalArgumentException("proportional location must be between 0.0 and 1.0.");
        if (orientation == VERTICAL_SPLIT) setDividerLocation((int) ((double) (getHeight() - getDividerSize()) * proportionalLocation));
        else setDividerLocation((int) ((double) (getWidth() - getDividerSize()) * proportionalLocation));
    }
    public int getDividerLocation() { return dividerLocation; }
    public void resetToPreferredSizes() { setDividerLocation(insLo() + prefOf(leftComponent)); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        Insets in = getInsets();
        Dimension a = leftComponent != null && leftComponent.isVisible() ? leftComponent.getPreferredSize() : new Dimension(0, 0);
        Dimension b = rightComponent != null && rightComponent.isVisible() ? rightComponent.getPreferredSize() : new Dimension(0, 0);
        if (orientation == HORIZONTAL_SPLIT) return new Dimension(a.width + b.width + dividerSize + in.left + in.right, Math.max(a.height, b.height) + in.top + in.bottom);
        return new Dimension(Math.max(a.width, b.width) + in.left + in.right, a.height + b.height + dividerSize + in.top + in.bottom);
    }
    public Dimension getMinimumSize() {
        if (minSize != null) return new Dimension(minSize);
        Insets in = getInsets();
        Dimension a = leftComponent != null && leftComponent.isVisible() ? leftComponent.getMinimumSize() : new Dimension(0, 0);
        Dimension b = rightComponent != null && rightComponent.isVisible() ? rightComponent.getMinimumSize() : new Dimension(0, 0);
        if (orientation == HORIZONTAL_SPLIT) return new Dimension(a.width + b.width + dividerSize + in.left + in.right, Math.max(a.height, b.height) + in.top + in.bottom);
        return new Dimension(Math.max(a.width, b.width) + in.left + in.right, a.height + b.height + dividerSize + in.top + in.bottom);
    }
    private void computeLoc() {
        int f = full();
        if (curLoc < 0) {
            curLoc = insLo() + prefOf(leftComponent);
            if (leftComponent == null || !leftComponent.isVisible()) curLoc = insLo();
        } else if (lastSize > 0 && lastSize != f) {
            int loc = curLoc + (int) (resizeWeight * (f - lastSize));
            int lo = getMinimumDividerLocation(), hi = getMaximumDividerLocation();
            if (hi >= lo) { if (loc > hi) loc = hi; if (loc < lo) loc = lo; }
            curLoc = loc;
        }
        int maxLoc = f - insHi() - dividerSize;
        if (curLoc > maxLoc) curLoc = maxLoc;
        if (curLoc < insLo()) curLoc = insLo();
        lastSize = f;
    }
    public void doLayout() {
        Insets in = getInsets();
        if (width <= 0 || height <= 0) { lastSize = 0; return; }
        computeLoc();
        boolean lv = leftComponent != null && leftComponent.isVisible(), rv = rightComponent != null && rightComponent.isVisible();
        int loc = curLoc;
        if (!lv) loc = insLo();
        if (!rv && lv) loc = full() - insHi() - dividerSize;
        if (orientation == HORIZONTAL_SPLIT) {
            if (leftComponent != null) leftComponent.setBounds(in.left, in.top, loc - in.left, height - in.top - in.bottom);
            if (rightComponent != null) rightComponent.setBounds(loc + dividerSize, in.top, width - in.right - loc - dividerSize, height - in.top - in.bottom);
        } else {
            if (leftComponent != null) leftComponent.setBounds(in.left, in.top, width - in.left - in.right, loc - in.top);
            if (rightComponent != null) rightComponent.setBounds(in.left, loc + dividerSize, width - in.left - in.right, height - in.bottom - loc - dividerSize);
        }
    }
    Rectangle dividerRect() {
        Insets in = getInsets();
        int loc = curLoc < 0 ? insLo() + prefOf(leftComponent) : curLoc;
        if (orientation == HORIZONTAL_SPLIT) return new Rectangle(loc, in.top, dividerSize, height - in.top - in.bottom);
        return new Rectangle(in.left, loc, width - in.left - in.right, dividerSize);
    }
    public boolean wantsMouse() { return true; }
    private int hitArrow(int mx, int my) {
        if (!oneTouchExpandable) return 0;
        Rectangle r = dividerRect();
        if (orientation == HORIZONTAL_SPLIT) {
            if (mx < r.x || mx >= r.x + r.width) return 0;
            if (my >= r.y + 2 && my < r.y + 2 + 8) return 1;
            if (my >= r.y + 12 && my < r.y + 12 + 8) return 2;
        } else {
            if (my < r.y || my >= r.y + r.height) return 0;
            if (mx >= r.x + 2 && mx < r.x + 10) return 1;
            if (mx >= r.x + 12 && mx < r.x + 20) return 2;
        }
        return 0;
    }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (e.getID() == MouseEvent.MOUSE_PRESSED && e.getButton() == 1) {
            Rectangle r = dividerRect();
            if (r.contains(e.getX(), e.getY())) {
                int h = hitArrow(e.getX(), e.getY());
                int maxLoc = full() - insHi() - dividerSize;
                int last = lastDividerLocation < 0 ? insLo() : lastDividerLocation;
                if (h == 1) {
                    if (curLoc >= maxLoc && last < maxLoc) setDividerLocation(last); else setDividerLocation(insLo());
                    return;
                } else if (h == 2) {
                    if (curLoc <= insLo() && last > insLo()) setDividerLocation(last); else setDividerLocation(maxLoc);
                    return;
                }
                dragging = true;
                dragOff = (orientation == HORIZONTAL_SPLIT ? e.getX() - r.x : e.getY() - r.y);
            }
        } else if (e.getID() == MouseEvent.MOUSE_RELEASED) dragging = false;
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        super.processMouseMotionEvent(e);
        if (dragging && e.getID() == MouseEvent.MOUSE_DRAGGED) {
            int p = (orientation == HORIZONTAL_SPLIT ? e.getX() : e.getY()) - dragOff;
            int lo = getMinimumDividerLocation(), hi = getMaximumDividerLocation();
            if (hi >= lo) { if (p > hi) p = hi; if (p < lo) p = lo; }
            if (p != curLoc) setDividerLocation(p);
        }
    }
    protected void paintComponent(Graphics g) {
        g.setColor(getBackground());
        g.fillRect(0, 0, width, height);
    }
    protected void paintChildren(Graphics g) {
        super.paintChildren(g);
        Rectangle r = dividerRect();
        Graphics dg = g.create(r.x, r.y, r.width, r.height);
        boolean hz = orientation == HORIZONTAL_SPLIT;
        dg.setColor(new Color(238, 238, 238));
        dg.fillRect(0, 0, r.width, r.height);
        int cx = r.width / 2, cy = r.height / 2;
        for (int i = -2; i <= 2; i++) {
            int px = hz ? cx - 1 : cx + i * 6 - 1, py = hz ? cy + i * 6 - 1 : cy - 1;
            dg.setColor(Color.WHITE); dg.fillRect(px, py, 2, 2);
            dg.setColor(new Color(122, 138, 153)); dg.fillRect(px + 1, py + 1, 1, 1);
        }
        if (oneTouchExpandable) {
            dg.setColor(new Color(51, 51, 51));
            if (hz) {
                dg.fillPolygon(new int[] { 2, 7, 7 }, new int[] { 6, 2, 10 }, 3);
                dg.fillPolygon(new int[] { 7, 2, 2 }, new int[] { 16, 12, 20 }, 3);
            } else {
                dg.fillPolygon(new int[] { 6, 2, 10 }, new int[] { 2, 7, 7 }, 3);
                dg.fillPolygon(new int[] { 12, 20, 16 }, new int[] { 2, 2, 7 }, 3);
            }
        }
        dg.setColor(new Color(122, 138, 153));
        if (hz) { dg.drawLine(0, 0, 0, r.height); dg.drawLine(r.width - 1, 0, r.width - 1, r.height); }
        else { dg.drawLine(0, 0, r.width, 0); dg.drawLine(0, r.height - 1, r.width, r.height - 1); }
        dg.dispose();
    }
}
