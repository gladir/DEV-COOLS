package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.ArrayList;
public abstract class AbstractButton extends JComponent implements SwingConstants, ItemSelectable {
    String text = "";
    Icon icon;
    boolean selected;
    String command;
    int hAlign = CENTER;
    boolean borderPainted = true, contentAreaFilled = true, focusPainted = true;
    ButtonGroup group;
    ArrayList<ActionListener> actionListeners = new ArrayList<>();
    ArrayList<ItemListener> itemListeners = new ArrayList<>();
    ArrayList<javax.swing.event.ChangeListener> changeListeners = new ArrayList<>();
    int mnemonic;
    public String getText() { return text; }
    public void setText(String t) { text = t == null ? "" : t; invalidate(); repaint(); }
    public Icon getIcon() { return icon; }
    public void setIcon(Icon i) { icon = i; invalidate(); repaint(); }
    public boolean isSelected() { return selected; }
    public void setSelected(boolean b) {
        if (selected != b) {
            selected = b;
            if (group != null && b) group.select(this);
            ItemEvent ie = new ItemEvent(this, ItemEvent.ITEM_STATE_CHANGED, this, b ? ItemEvent.SELECTED : ItemEvent.DESELECTED);
            for (ItemListener l : new ArrayList<>(itemListeners)) l.itemStateChanged(ie);
            javax.swing.event.ChangeEvent ce = new javax.swing.event.ChangeEvent(this);
            for (javax.swing.event.ChangeListener l : new ArrayList<>(changeListeners)) l.stateChanged(ce);
            repaint();
        }
    }
    public void setActionCommand(String c) { command = c; }
    public String getActionCommand() { return command != null ? command : text; }
    public void setMnemonic(int m) { mnemonic = m; }
    public void setMnemonic(char m) { mnemonic = m; }
    public void setHorizontalAlignment(int a) { hAlign = a; }
    public void setBorderPainted(boolean b) { borderPainted = b; repaint(); }
    public void setContentAreaFilled(boolean b) { contentAreaFilled = b; repaint(); }
    public void setFocusPainted(boolean b) { focusPainted = b; }
    public void setMargin(Insets m) { }
    public void setRolloverEnabled(boolean b) { }
    public void setHorizontalTextPosition(int p) { }
    public void setVerticalTextPosition(int p) { }
    public void setDefaultCapable(boolean b) { }
    public void addActionListener(ActionListener l) { actionListeners.add(l); }
    public void removeActionListener(ActionListener l) { actionListeners.remove(l); }
    public ActionListener[] getActionListeners() { return actionListeners.toArray(new ActionListener[0]); }
    public void addItemListener(ItemListener l) { itemListeners.add(l); }
    public void removeItemListener(ItemListener l) { itemListeners.remove(l); }
    public void addChangeListener(javax.swing.event.ChangeListener l) { changeListeners.add(l); }
    public Object[] getSelectedObjects() { return selected ? new Object[] { text } : null; }
    public void doClick() { fire(); }
    public void doClick(int ms) { fire(); }
    public void setAction(Action a) { }
    public boolean focusTraversable() { return true; }
    public boolean wantsMouse() { return true; }
    public boolean wantsKeys() { return true; }
    protected void fireAction() {
        ActionEvent ae = new ActionEvent(this, ActionEvent.ACTION_PERFORMED, getActionCommand(), System.currentTimeMillis(), 0);
        for (ActionListener l : new ArrayList<>(actionListeners)) l.actionPerformed(ae);
    }
    void fire() { if (!enabled) return; clicked(); fireAction(); repaint(); }
    void clicked() { }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        Insets in = getInsets();
        int w = fm.stringWidth(text) + (icon != null ? icon.getIconWidth() + 4 : 0);
        int h = Math.max(fm.getHeight(), icon != null ? icon.getIconHeight() : 0);
        return new Dimension(w + in.left + in.right + extraW(), h + in.top + in.bottom + extraH());
    }
    int extraW() { return 0; }
    int extraH() { return 0; }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (!enabled) return;
        int id = e.getID();
        if (id == MouseEvent.MOUSE_PRESSED && e.getButton() == 1) { pressed = true; repaint(); }
        else if (id == MouseEvent.MOUSE_RELEASED) {
            boolean fire = pressed && contains(e.getX(), e.getY());
            pressed = false;
            repaint();
            if (fire) fire();
        } else if (id == MouseEvent.MOUSE_ENTERED || id == MouseEvent.MOUSE_EXITED) repaint();
    }
    protected void processKeyEvent(KeyEvent e) {
        super.processKeyEvent(e);
        if (e.getID() == KeyEvent.KEY_PRESSED && enabled && (e.getKeyCode() == KeyEvent.VK_SPACE || e.getKeyCode() == KeyEvent.VK_ENTER)) fire();
    }
    static void gradient(Graphics g, int x, int y, int w, int h, boolean pressed, boolean hover) {
        for (int j = 0; j < h; j++) {
            double t = h <= 1 ? 0 : (double) j / (h - 1);
            int r, gg, b;
            if (pressed) { r = 184 - (int) (20 * t); gg = 207 - (int) (20 * t); b = 229 - (int) (12 * t); }
            else if (t < 0.18) { double k = t / 0.18; r = 238 + (int) (15 * k); gg = 244 + (int) (9 * k); b = 249 + (int) (5 * k); }
            else { double k = (t - 0.18) / 0.82; r = 243 - (int) (47 * k); gg = 247 - (int) (32 * k); b = 251 - (int) (17 * k); if (hover) { r += 6; gg += 6; b += 3; } }
            g.setColor(new Color(Math.min(255, r), Math.min(255, gg), Math.min(255, b)));
            g.drawLine(x, y + j, x + w - 1, y + j);
        }
    }
}
