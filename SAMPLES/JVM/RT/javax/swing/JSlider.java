package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.ArrayList;
public class JSlider extends JComponent {
    private int min, max = 100, value = 50;
    private final int orient;
    private final ArrayList<javax.swing.event.ChangeListener> cl = new ArrayList<>();
    public JSlider() { this(0, 100, 50); }
    public JSlider(int min, int max, int value) { this(0, min, max, value); }
    public JSlider(int orientation, int min, int max, int value) { this.orient = orientation; this.min = min; this.max = max; this.value = value; }
    public int getValue() { return value; }
    public void setValue(int v) { v = Math.max(min, Math.min(max, v)); if (v != value) { value = v; javax.swing.event.ChangeEvent e = new javax.swing.event.ChangeEvent(this); for (javax.swing.event.ChangeListener l : new ArrayList<>(cl)) l.stateChanged(e); repaint(); } }
    public void setMajorTickSpacing(int n) { }
    public void setMinorTickSpacing(int n) { }
    public void setPaintTicks(boolean b) { }
    public void setPaintLabels(boolean b) { }
    public void addChangeListener(javax.swing.event.ChangeListener l) { cl.add(l); }
    public boolean focusTraversable() { return true; }
    public boolean wantsMouse() { return true; }
    public Dimension getPreferredSize() { return prefSize != null ? new Dimension(prefSize) : (orient == 0 ? new Dimension(200, 24) : new Dimension(24, 200)); }
    protected void processMouseEvent(MouseEvent e) { if (e.getID() == MouseEvent.MOUSE_PRESSED) set(e); }
    protected void processMouseMotionEvent(MouseEvent e) { if (e.getID() == MouseEvent.MOUSE_DRAGGED) set(e); }
    void set(MouseEvent e) { int len = (orient == 0 ? width : height) - 12; int p = (orient == 0 ? e.getX() : e.getY()) - 6; setValue(min + p * (max - min) / Math.max(1, len)); }
    protected void paintComponent(Graphics g) {
        int len = (orient == 0 ? width : height) - 12;
        int p = 6 + len * (value - min) / Math.max(1, max - min);
        g.setColor(new Color(184, 207, 229));
        if (orient == 0) { g.fillRect(6, height / 2 - 2, len, 4); g.setColor(new Color(122, 138, 153)); g.drawRect(6, height / 2 - 2, len, 4); AbstractButton.gradient(g, p - 6, height / 2 - 8, 12, 16, false, false); g.drawRect(p - 6, height / 2 - 8, 12, 16); }
        else { g.fillRect(width / 2 - 2, 6, 4, len); g.setColor(new Color(122, 138, 153)); g.drawRect(width / 2 - 2, 6, 4, len); AbstractButton.gradient(g, width / 2 - 8, p - 6, 16, 12, false, false); g.drawRect(width / 2 - 8, p - 6, 16, 12); }
    }
}
