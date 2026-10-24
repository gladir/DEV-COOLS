package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.List;
public class PopupWindow extends Window {
    private final List<JMenuItem> items;
    private final JMenu menu;
    private int hot = -1;
    public PopupWindow(JMenu menu, List<JMenuItem> items, int w) {
        super((Window) null);
        this.menu = menu; this.items = items;
        undecorated = true; popup = true;
        int h = 4;
        for (JMenuItem i : items) h += i.getText() == null ? 5 : 20;
        setSize(w, h);
        positioned = true;
    }
    void show(int x, int y) { setLocation(x, y); setVisible(true); }
    public boolean wantsMouse() { return true; }
    int rowAt(int ly) {
        int y = 2;
        for (int k = 0; k < items.size(); k++) { int rh = items.get(k).getText() == null ? 5 : 20; if (ly >= y && ly < y + rh) return k; y += rh; }
        return -1;
    }
    protected void processMouseEvent(MouseEvent e) {
        if (e.getID() == MouseEvent.MOUSE_RELEASED || e.getID() == MouseEvent.MOUSE_CLICKED) {
            if (e.getID() == MouseEvent.MOUSE_RELEASED) {
                int k = rowAt(e.getY());
                if (k >= 0 && items.get(k).getText() != null && items.get(k).isEnabled()) {
                    JMenuItem it = items.get(k);
                    setVisible(false);
                    if (it instanceof JMenu) ((JMenu) it).open(); else { it.clicked(); it.fireAction(); }
                }
            }
        }
    }
    protected void processMouseMotionEvent(MouseEvent e) { int k = rowAt(e.getY()); if (k != hot) { hot = k; repaint(); } }
    protected void paintContent(Graphics g) {
        g.setColor(new Color(238, 238, 238)); g.fillRect(0, 0, width, height);
        g.setColor(new Color(122, 138, 153)); g.drawRect(0, 0, width - 1, height - 1);
        int y = 2;
        for (int k = 0; k < items.size(); k++) {
            JMenuItem it = items.get(k);
            if (it.getText() == null) { g.setColor(new Color(184, 207, 229)); g.drawLine(2, y + 2, width - 3, y + 2); y += 5; continue; }
            if (k == hot) { g.setColor(new Color(184, 207, 229)); g.fillRect(1, y, width - 2, 20); }
            FontMetrics fm = g.getFontMetrics(it.getFont());
            g.setFont(it.getFont());
            g.setColor(it.isEnabled() ? new Color(51, 51, 51) : new Color(153, 153, 153));
            if (it instanceof JCheckBoxMenuItem && it.isSelected()) g.drawString("x", 6, y + (20 - fm.getHeight()) / 2 + fm.getAscent());
            g.drawString(it.getText(), 18, y + (20 - fm.getHeight()) / 2 + fm.getAscent());
            y += 20;
        }
    }
}
