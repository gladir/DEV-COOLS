package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.ArrayList;
import javax.swing.text.JTextComponent;
public class JTextField extends JTextComponent {
    int columns;
    int hAlign = SwingConstants.LEADING;
    ArrayList<ActionListener> actionListeners = new ArrayList<>();
    public JTextField() { this("", 0); }
    public JTextField(int columns) { this("", columns); }
    public JTextField(String text) { this(text, 0); }
    public JTextField(String text, int columns) { sb.append(text == null ? "" : text); caret = sb.length(); this.columns = columns; opaque = true; }
    public void setColumns(int c) { columns = c; invalidate(); }
    public int getColumns() { return columns; }
    public void setHorizontalAlignment(int a) { hAlign = a; }
    public void addActionListener(ActionListener l) { actionListeners.add(l); }
    public void removeActionListener(ActionListener l) { actionListeners.remove(l); }
    public Insets getInsets() { return new Insets(3, 5, 3, 5); }
    protected void enter() { ActionEvent ae = new ActionEvent(this, ActionEvent.ACTION_PERFORMED, getText()); for (ActionListener l : new ArrayList<>(actionListeners)) l.actionPerformed(ae); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        int w = columns > 0 ? columns * 8 : Math.max(fm.stringWidth(getText()), 8);
        Insets in = getInsets();
        return new Dimension(w + in.left + in.right, fm.getHeight() + in.top + in.bottom + 4);
    }
    protected String shown() { return getText(); }
    public int getBaseline(int w, int h) {
        if (w < 0 || h < 0) throw new IllegalArgumentException("Width and height must be >= 0");
        FontMetrics fm = new FontMetrics(getFont());
        return (h - fm.getHeight()) / 2 + fm.getAscent();
    }
    public BaselineResizeBehavior getBaselineResizeBehavior() { return BaselineResizeBehavior.CENTER_OFFSET; }
    protected void paintComponent(Graphics g) {
        g.setColor(editable && enabled ? Color.WHITE : new Color(238, 238, 238));
        g.fillRect(0, 0, width, height);
        g.setColor(new Color(122, 138, 153));
        g.drawRect(0, 0, width - 1, height - 1);
        g.setColor(new Color(184, 207, 229));
        g.drawLine(1, 1, width - 2, 1);
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        String s = shown();
        Insets in = getInsets();
        int tx = in.left;
        int tw = fm.stringWidth(s);
        if (hAlign == SwingConstants.CENTER) tx = (width - tw) / 2; else if (hAlign == SwingConstants.RIGHT) tx = width - in.right - tw;
        int ty = (height - fm.getHeight()) / 2 + fm.getAscent();
        int off = 0;
        int avail = width - in.left - in.right;
        int cx = fm.stringWidth(s.substring(0, Math.min(caret, s.length())));
        if (cx > avail - 2) off = cx - avail + 2;
        Graphics cg = g.create(in.left, 1, avail, height - 2);
        cg.setFont(getFont());
        if (selStart >= 0 && selEnd > selStart) {
            cg.setColor(new Color(184, 207, 229));
            cg.fillRect(tx - in.left - off + fm.stringWidth(s.substring(0, selStart)), 2, fm.stringWidth(s.substring(selStart, Math.min(selEnd, s.length()))), height - 4);
        }
        cg.setColor(enabled ? (foreground != null ? foreground : new Color(51, 51, 51)) : new Color(153, 153, 153));
        cg.drawString(s, tx - in.left - off, ty - 1);
        if (isFocusOwner() && editable) { cg.setColor(Color.BLACK); cg.drawLine(tx - in.left - off + cx, 3, tx - in.left - off + cx, height - 4); }
        cg.dispose();
    }
}
