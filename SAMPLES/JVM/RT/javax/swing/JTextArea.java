package javax.swing;
import java.awt.*;
import java.awt.event.*;
import javax.swing.text.JTextComponent;
public class JTextArea extends JTextComponent {
    int rows, columns;
    boolean wrap;
    public JTextArea() { this("", 0, 0); }
    public JTextArea(int rows, int columns) { this("", rows, columns); }
    public JTextArea(String text) { this(text, 0, 0); }
    public JTextArea(String text, int rows, int columns) { sb.append(text == null ? "" : text); caret = sb.length(); this.rows = rows; this.columns = columns; opaque = true; }
    public void append(String s) { sb.append(s); caret = sb.length(); changed(); }
    public void insert(String s, int pos) { sb.insert(pos, s); changed(); }
    public void replaceRange(String s, int a, int b) { sb.replace(a, b, s); changed(); }
    public void setLineWrap(boolean b) { wrap = b; }
    public void setWrapStyleWord(boolean b) { }
    public void setRows(int r) { rows = r; }
    public void setColumns(int c) { columns = c; }
    public void setTabSize(int n) { }
    public int getLineCount() { int n = 1; for (int i = 0; i < sb.length(); i++) if (sb.charAt(i) == '\n') n++; return n; }
    public boolean isMultiLine() { return true; }
    public Insets getInsets() { return new Insets(3, 5, 3, 5); }
    protected void enter() { insert("\n"); }
    protected int lineStart() { int i = caret; while (i > 0 && sb.charAt(i - 1) != '\n') i--; return i; }
    protected int lineEnd() { int i = caret; while (i < sb.length() && sb.charAt(i) != '\n') i++; return i; }
    protected void up() { int ls = lineStart(); if (ls == 0) return; int col = caret - ls; int ps = ls - 1; while (ps > 0 && sb.charAt(ps - 1) != '\n') ps--; caret = Math.min(ps + col, ls - 1); repaint(); }
    protected void down() { int le = lineEnd(); if (le >= sb.length()) return; int col = caret - lineStart(); int ns = le + 1; int ne = ns; while (ne < sb.length() && sb.charAt(ne) != '\n') ne++; caret = Math.min(ns + col, ne); repaint(); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        int r = rows > 0 ? rows : getLineCount();
        int c = columns > 0 ? columns : 20;
        Insets in = getInsets();
        return new Dimension(c * 8 + in.left + in.right, r * fm.getHeight() + in.top + in.bottom);
    }
    protected void paintComponent(Graphics g) {
        g.setColor(editable && enabled ? Color.WHITE : new Color(238, 238, 238));
        g.fillRect(0, 0, width, height);
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(new Color(51, 51, 51));
        Insets in = getInsets();
        String[] lines = getText().split("\n", -1);
        int y = in.top;
        int pos = 0;
        for (String ln : lines) {
            g.drawString(ln, in.left, y + fm.getAscent());
            if (isFocusOwner() && caret >= pos && caret <= pos + ln.length()) {
                int cx = in.left + fm.stringWidth(ln.substring(0, caret - pos));
                g.drawLine(cx, y, cx, y + fm.getHeight() - 1);
            }
            pos += ln.length() + 1;
            y += fm.getHeight();
        }
    }
}
