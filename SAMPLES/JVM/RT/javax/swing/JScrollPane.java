package javax.swing;
import java.awt.*;
import java.awt.event.*;
public class JScrollPane extends JComponent {
    private Component view;
    int sx, sy;
    boolean dragV, dragH;
    int dragOff;
    public static final int VERTICAL_SCROLLBAR_AS_NEEDED = 20, VERTICAL_SCROLLBAR_NEVER = 21, VERTICAL_SCROLLBAR_ALWAYS = 22, HORIZONTAL_SCROLLBAR_AS_NEEDED = 30, HORIZONTAL_SCROLLBAR_NEVER = 31, HORIZONTAL_SCROLLBAR_ALWAYS = 32;
    public JScrollPane() { opaque = true; }
    public JScrollPane(Component view) { this(); setViewportView(view); }
    public JScrollPane(Component view, int v, int h) { this(view); }
    public void setViewportView(Component v) { if (view != null) super.remove(view); view = v; if (v != null) { v.parent = this; comps.add(v); } invalidate(); }
    public Component getViewport() { return view; }
    public JScrollPane getVerticalScrollBar() { return this; }
    public void setBlockIncrement(int n) { }
    public void setUnitIncrement(int n) { }
    public void setValue(int v) { sy = v; repaint(); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        Dimension d = view == null ? new Dimension(0, 0) : view.getPreferredSize();
        return new Dimension(Math.min(d.width, 400) + 2, Math.min(d.height, 300) + 2);
    }
    Dimension vsize() { return view == null ? new Dimension(0, 0) : view.getPreferredSize(); }
    boolean needV() { return vsize().height > height - 2; }
    boolean needH() { return vsize().width > width - 2 - (needV() ? 14 : 0); }
    int viewW() { return width - 2 - (needV() ? 14 : 0); }
    int viewH() { return height - 2 - (needH() ? 14 : 0); }
    public void doLayout() {
        if (view == null) return;
        Dimension d = vsize();
        int vw = Math.max(d.width, viewW()), vh = Math.max(d.height, viewH());
        sy = Math.max(0, Math.min(sy, vh - viewH())); sx = Math.max(0, Math.min(sx, vw - viewW()));
        view.setBounds(1 - sx, 1 - sy, vw, vh);
    }
    public boolean wantsMouse() { return true; }
    protected void processMouseEvent(MouseEvent e) {
        int id = e.getID();
        if (id == MouseEvent.MOUSE_PRESSED) {
            if (needV() && e.getX() >= width - 15) {
                int th = thumbH(), ty = thumbY();
                if (e.getY() >= ty && e.getY() < ty + th) { dragV = true; dragOff = e.getY() - ty; }
                else { sy += e.getY() < ty ? -viewH() : viewH(); doLayout(); repaint(); }
            }
        } else if (id == MouseEvent.MOUSE_RELEASED) { dragV = false; dragH = false; }
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        if (dragV) {
            int track = viewH() - thumbH();
            int total = vsize().height - viewH();
            if (track > 0) { sy = (e.getY() - dragOff - 1) * total / track; doLayout(); repaint(); }
        }
    }
    protected void processMouseWheelEvent(MouseWheelEvent e) { sy += e.getWheelRotation() * 20; doLayout(); repaint(); }
    int thumbH() { int th = vsize().height; return Math.max(16, viewH() * viewH() / Math.max(1, th)); }
    int thumbY() { int total = vsize().height - viewH(); int track = viewH() - thumbH(); return 1 + (total <= 0 ? 0 : sy * track / total); }
    protected void paintComponent(Graphics g) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); }
    protected void paintChildren(Graphics g) {
        if (view == null) return;
        Graphics cg = g.create(1, 1, viewW(), viewH());
        cg.translate(-1, -1);
        Graphics vg = cg.create(view.getX(), view.getY(), view.getWidth(), view.getHeight());
        view.paint(vg);
    }
    public void paint(Graphics g) {
        paintComponent(g);
        paintChildren(g);
        g.setColor(new Color(122, 138, 153));
        g.drawRect(0, 0, width - 1, height - 1);
        if (needV()) {
            g.setColor(new Color(238, 238, 238)); g.fillRect(width - 15, 1, 14, height - 2);
            AbstractButton.gradient(g, width - 14, thumbY(), 12, thumbH(), dragV, false);
            g.setColor(new Color(122, 138, 153)); g.drawRect(width - 14, thumbY(), 12, thumbH());
        }
    }
}
