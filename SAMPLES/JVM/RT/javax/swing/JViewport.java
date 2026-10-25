package javax.swing;
import java.awt.*;
import java.util.ArrayList;
import javax.swing.event.*;
public class JViewport extends JComponent {
    private Component view;
    private int vx, vy;
    private final ArrayList<ChangeListener> changeListeners = new ArrayList<>();
    public JViewport() { opaque = true; background = new Color(238, 238, 238); }
    public Component getView() { return view; }
    public void setView(Component v) {
        if (view != null) { remove(view); view = null; }
        if (v != null) { view = v; add(v); }
        vx = 0; vy = 0;
        invalidate();
        fireStateChanged();
        repaint();
    }
    public Point getViewPosition() { return new Point(vx, vy); }
    public void setViewPosition(Point p) {
        if (view == null) return;
        int nx = p.x, ny = p.y;
        if (nx != vx || ny != vy) {
            vx = nx; vy = ny;
            view.setLocation(-vx, -vy);
            fireStateChanged();
            repaint();
        }
    }
    public Dimension getViewSize() { return view == null ? new Dimension(0, 0) : view.getSize(); }
    public void setViewSize(Dimension d) {
        if (view == null) return;
        if (view.getWidth() != d.width || view.getHeight() != d.height) {
            view.setSize(d);
            fireStateChanged();
        }
    }
    public Dimension getExtentSize() { return getSize(); }
    public Rectangle getViewRect() { return new Rectangle(vx, vy, width, height); }
    public Dimension toViewCoordinates(Dimension size) { return new Dimension(size); }
    public Point toViewCoordinates(Point p) { return new Point(p.x + vx, p.y + vy); }
    public void scrollRectToVisible(Rectangle r) {
        if (view == null) return;
        int dx = positionAdjustment(width, r.width, r.x);
        int dy = positionAdjustment(height, r.height, r.y);
        if (dx != 0 || dy != 0) {
            int nx = vx - dx, ny = vy - dy;
            if (view.isValid()) {
                if (nx + width > view.getWidth()) nx = Math.max(0, view.getWidth() - width); else if (nx < 0) nx = 0;
                if (ny + height > view.getHeight()) ny = Math.max(0, view.getHeight() - height); else if (ny < 0) ny = 0;
            }
            setViewPosition(new Point(nx, ny));
        }
    }
    private int positionAdjustment(int parentWidth, int childWidth, int childAt) {
        if (childAt >= 0 && childWidth + childAt <= parentWidth) return 0;
        if (childAt <= 0 && childWidth + childAt >= parentWidth) return 0;
        if (childAt > 0 && childWidth <= parentWidth) return -childAt + (parentWidth - childWidth);
        if (childAt >= 0 && childWidth >= parentWidth) return -childAt;
        if (childAt <= 0 && childWidth <= parentWidth) return -childAt;
        if (childAt < 0 && childWidth >= parentWidth) return -childAt + (parentWidth - childWidth);
        return 0;
    }
    public void addChangeListener(ChangeListener l) { changeListeners.add(l); }
    public void removeChangeListener(ChangeListener l) { changeListeners.remove(l); }
    public ChangeListener[] getChangeListeners() { return changeListeners.toArray(new ChangeListener[0]); }
    void fireStateChanged() {
        if (changeListeners.isEmpty()) return;
        ChangeEvent e = new ChangeEvent(this);
        for (ChangeListener l : new ArrayList<>(changeListeners)) l.stateChanged(e);
    }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        if (view == null) return new Dimension(0, 0);
        if (view instanceof Scrollable s) return s.getPreferredScrollableViewportSize();
        return view.getPreferredSize();
    }
    public Dimension getMinimumSize() { return minSize != null ? new Dimension(minSize) : new Dimension(4, 4); }
    public void doLayout() {
        if (view == null) return;
        Dimension viewPref = view.getPreferredSize();
        Scrollable sc = view instanceof Scrollable ? (Scrollable) view : null;
        Dimension vs = new Dimension(viewPref);
        if (sc != null) {
            if (sc.getScrollableTracksViewportWidth()) vs.width = width;
            if (sc.getScrollableTracksViewportHeight()) vs.height = height;
        }
        int px = vx, py = vy;
        if (px + width > vs.width) px = Math.max(0, vs.width - width);
        if (py + height > vs.height) py = Math.max(0, vs.height - height);
        if (sc == null) {
            if (px == 0 && width > viewPref.width) vs.width = width;
            if (py == 0 && height > viewPref.height) vs.height = height;
        }
        vx = px; vy = py;
        boolean changed = view.getWidth() != vs.width || view.getHeight() != vs.height || view.getX() != -vx || view.getY() != -vy;
        view.setBounds(-vx, -vy, vs.width, vs.height);
        if (changed) fireStateChanged();
    }
    protected void paintComponent(Graphics g) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); }
}
