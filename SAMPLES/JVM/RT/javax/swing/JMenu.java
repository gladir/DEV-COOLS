package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.ArrayList;
public class JMenu extends JMenuItem {
    ArrayList<JMenuItem> items = new ArrayList<>();
    PopupWindow popup;
    public JMenu() { }
    public JMenu(String text) { super(text); }
    public JMenuItem add(JMenuItem item) { items.add(item); return item; }
    public Component add(Component c) { if (c instanceof JMenuItem) items.add((JMenuItem) c); return c; }
    public JMenuItem add(String text) { JMenuItem i = new JMenuItem(text); items.add(i); return i; }
    public void addSeparator() { items.add(new JMenuItem(null)); }
    public int getItemCount() { return items.size(); }
    public JMenuItem getItem(int i) { return items.get(i); }
    void clicked() { open(); }
    void open() {
        if (popup != null && popup.isVisible()) { popup.setVisible(false); return; }
        int w = 40;
        FontMetrics fm = new FontMetrics(getFont());
        for (JMenuItem i : items) w = Math.max(w, fm.stringWidth(i.getText()) + 36);
        popup = new PopupWindow(this, items, w);
        Point p = getLocationOnScreen();
        popup.show(p.x, p.y + height);
    }
    protected void paintComponent(Graphics g) {
        if (popup != null && popup.isVisible()) { g.setColor(new Color(184, 207, 229)); g.fillRect(0, 0, width, height); }
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(new Color(51, 51, 51));
        g.drawString(text, 6, (height - fm.getHeight()) / 2 + fm.getAscent());
    }
    int extraW() { return 12; }
    int extraH() { return 6; }
}
