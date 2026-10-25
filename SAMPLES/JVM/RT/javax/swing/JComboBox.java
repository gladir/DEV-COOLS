package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
public class JComboBox<E> extends JComponent implements ItemSelectable {
    private final ArrayList<E> items = new ArrayList<>();
    private int sel = -1;
    private boolean editable;
    private final ArrayList<ActionListener> al = new ArrayList<>();
    private final ArrayList<ItemListener> il = new ArrayList<>();
    ComboPopup popupW;
    public JComboBox() { }
    public JComboBox(E[] arr) { for (E e : arr) items.add(e); if (!items.isEmpty()) sel = 0; }
    public JComboBox(Vector<E> v) { items.addAll(v); if (!items.isEmpty()) sel = 0; }
    public void addItem(E e) { items.add(e); if (sel < 0) sel = 0; repaint(); }
    public void insertItemAt(E e, int i) { items.add(i, e); }
    public void removeItem(Object e) { int i = items.indexOf(e); if (i >= 0) removeItemAt(i); }
    public void removeItemAt(int i) { items.remove(i); if (sel >= items.size()) sel = items.size() - 1; repaint(); }
    public void removeAllItems() { items.clear(); sel = -1; repaint(); }
    public int getItemCount() { return items.size(); }
    public E getItemAt(int i) { return items.get(i); }
    public Object getSelectedItem() { return sel >= 0 && sel < items.size() ? items.get(sel) : null; }
    public void setSelectedItem(Object o) { int i = items.indexOf(o); if (i >= 0) setSelectedIndex(i); }
    public int getSelectedIndex() { return sel; }
    public void setSelectedIndex(int i) {
        if (i != sel) {
            sel = i;
            ItemEvent ie = new ItemEvent(this, ItemEvent.ITEM_STATE_CHANGED, getSelectedItem(), ItemEvent.SELECTED);
            for (ItemListener l : new ArrayList<>(il)) l.itemStateChanged(ie);
            ActionEvent ae = new ActionEvent(this, ActionEvent.ACTION_PERFORMED, "comboBoxChanged");
            for (ActionListener l : new ArrayList<>(al)) l.actionPerformed(ae);
            repaint();
        }
    }
    public void setEditable(boolean b) { editable = b; }
    public void setMaximumRowCount(int n) { }
    public void addActionListener(ActionListener l) { al.add(l); }
    public void removeActionListener(ActionListener l) { al.remove(l); }
    public void addItemListener(ItemListener l) { il.add(l); }
    public void removeItemListener(ItemListener l) { il.remove(l); }
    public Object[] getSelectedObjects() { return new Object[] { getSelectedItem() }; }
    public boolean focusTraversable() { return true; }
    public int getBaseline(int w, int h) {
        if (w < 0 || h < 0) throw new IllegalArgumentException("Width and height must be >= 0");
        FontMetrics fm = new FontMetrics(getFont());
        return (h - fm.getHeight()) / 2 + fm.getAscent();
    }
    public BaselineResizeBehavior getBaselineResizeBehavior() { return BaselineResizeBehavior.CENTER_OFFSET; }
    public boolean wantsMouse() { return true; }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        int w = 20;
        for (E e : items) w = Math.max(w, fm.stringWidth(String.valueOf(e)));
        return new Dimension(w + 30, fm.getHeight() + 12);
    }
    protected void processMouseEvent(MouseEvent e) {
        if (e.getID() == MouseEvent.MOUSE_PRESSED && enabled) {
            if (popupW != null && popupW.isVisible()) { popupW.setVisible(false); return; }
            popupW = new ComboPopup(this);
            Point p = getLocationOnScreen();
            popupW.setSize(width, items.size() * 18 + 2);
            popupW.setLocation(p.x, p.y + height);
            popupW.setVisible(true);
        }
    }
    java.util.List<E> items() { return items; }
    protected void paintComponent(Graphics g) {
        g.setColor(Color.WHITE); g.fillRect(0, 0, width, height);
        AbstractButton.gradient(g, width - 18, 1, 17, height - 2, false, false);
        g.setColor(new Color(122, 138, 153)); g.drawRect(0, 0, width - 1, height - 1); g.drawLine(width - 19, 0, width - 19, height - 1);
        g.setColor(new Color(51, 51, 51));
        int ax = width - 14, ay = height / 2 - 2;
        g.fillPolygon(new int[] { ax, ax + 8, ax + 4 }, new int[] { ay, ay, ay + 4 }, 3);
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        Object s = getSelectedItem();
        g.drawString(s == null ? "" : String.valueOf(s), 5, (height - fm.getHeight()) / 2 + fm.getAscent());
    }
    static class ComboPopup extends Window {
        final JComboBox<?> box;
        int hot = -1;
        ComboPopup(JComboBox<?> box) { super((Window) null); this.box = box; undecorated = true; popup = true; positioned = true; }
        public boolean wantsMouse() { return true; }
        protected void processMouseEvent(MouseEvent e) {
            if (e.getID() == MouseEvent.MOUSE_RELEASED || e.getID() == MouseEvent.MOUSE_CLICKED) {
                int k = (e.getY() - 1) / 18;
                if (k >= 0 && k < box.items().size() && e.getID() == MouseEvent.MOUSE_RELEASED) { setVisible(false); box.setSelectedIndex(k); }
            }
        }
        protected void processMouseMotionEvent(MouseEvent e) { int k = (e.getY() - 1) / 18; if (k != hot) { hot = k; repaint(); } }
        protected void paintContent(Graphics g) {
            g.setColor(Color.WHITE); g.fillRect(0, 0, width, height);
            g.setColor(new Color(122, 138, 153)); g.drawRect(0, 0, width - 1, height - 1);
            FontMetrics fm = g.getFontMetrics(box.getFont());
            g.setFont(box.getFont());
            for (int i = 0; i < box.items().size(); i++) {
                if (i == hot) { g.setColor(new Color(184, 207, 229)); g.fillRect(1, 1 + i * 18, width - 2, 18); }
                g.setColor(new Color(51, 51, 51));
                g.drawString(String.valueOf(box.items().get(i)), 5, 1 + i * 18 + (18 - fm.getHeight()) / 2 + fm.getAscent());
            }
        }
    }
}
