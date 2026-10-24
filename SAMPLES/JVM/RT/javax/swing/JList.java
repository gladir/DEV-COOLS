package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import javax.swing.event.*;
public class JList<E> extends JComponent {
    private final ArrayList<E> items = new ArrayList<>();
    private int sel = -1;
    private final ArrayList<ListSelectionListener> ll = new ArrayList<>();
    public JList() { opaque = true; }
    public JList(E[] arr) { this(); for (E e : arr) items.add(e); }
    public JList(Vector<E> v) { this(); items.addAll(v); }
    public JList(DefaultListModel<E> m) { this(); for (int i = 0; i < m.getSize(); i++) items.add(m.getElementAt(i)); model = m; }
    DefaultListModel<E> model;
    void sync() { if (model != null) { items.clear(); for (int i = 0; i < model.getSize(); i++) items.add(model.getElementAt(i)); } }
    public void setListData(E[] arr) { items.clear(); for (E e : arr) items.add(e); invalidate(); repaint(); }
    public void setModel(DefaultListModel<E> m) { model = m; sync(); invalidate(); repaint(); }
    public void setSelectionMode(int m) { }
    public void setVisibleRowCount(int n) { }
    public int getSelectedIndex() { return sel; }
    public E getSelectedValue() { sync(); return sel >= 0 && sel < items.size() ? items.get(sel) : null; }
    public void setSelectedIndex(int i) { sel = i; repaint(); fire(); }
    public void clearSelection() { sel = -1; repaint(); }
    public boolean isSelectionEmpty() { return sel < 0; }
    public void addListSelectionListener(ListSelectionListener l) { ll.add(l); }
    void fire() { ListSelectionEvent e = new ListSelectionEvent(this, sel, sel, false); for (ListSelectionListener l : new ArrayList<>(ll)) l.valueChanged(e); }
    public boolean focusTraversable() { return true; }
    public boolean wantsMouse() { return true; }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        sync();
        FontMetrics fm = new FontMetrics(getFont());
        int w = 20;
        for (E e : items) w = Math.max(w, fm.stringWidth(String.valueOf(e)));
        return new Dimension(w + 12, Math.max(1, items.size()) * 18 + 4);
    }
    protected void processMouseEvent(MouseEvent e) {
        if (e.getID() == MouseEvent.MOUSE_PRESSED) { sync(); int k = (e.getY() - 2) / 18; if (k >= 0 && k < items.size()) { sel = k; repaint(); fire(); } }
    }
    protected void processKeyEvent(KeyEvent e) {
        if (e.getID() == KeyEvent.KEY_PRESSED) {
            if (e.getKeyCode() == KeyEvent.VK_DOWN && sel < items.size() - 1) { sel++; repaint(); fire(); }
            if (e.getKeyCode() == KeyEvent.VK_UP && sel > 0) { sel--; repaint(); fire(); }
        }
    }
    protected void paintComponent(Graphics g) {
        sync();
        g.setColor(Color.WHITE); g.fillRect(0, 0, width, height);
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        for (int i = 0; i < items.size(); i++) {
            int y = 2 + i * 18;
            if (i == sel) { g.setColor(new Color(184, 207, 229)); g.fillRect(0, y, width, 18); }
            g.setColor(new Color(51, 51, 51));
            g.drawString(String.valueOf(items.get(i)), 5, y + (18 - fm.getHeight()) / 2 + fm.getAscent());
        }
    }
}
