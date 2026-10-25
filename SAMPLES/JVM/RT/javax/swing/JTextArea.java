package javax.swing;
import java.awt.*;
import java.awt.event.*;
import javax.swing.text.JTextComponent;
public class JTextArea extends JTextComponent implements Scrollable {
    int rows, columns;
    boolean wrap;
    public JTextArea() { this("", 0, 0); }
    public JTextArea(int rows, int columns) { this("", rows, columns); }
    public JTextArea(String text) { this(text, 0, 0); }
    public JTextArea(String text, int rows, int columns) { sb.append(text == null ? "" : text); caret = sb.length(); this.rows = rows; this.columns = columns; opaque = true; }
    public void append(String s) { sb.append(s); caret = sb.length(); changed(); scrollToCaret(); }
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
    Dimension content() {
        FontMetrics fm = new FontMetrics(getFont());
        String[] lines = getText().split("\n", -1);
        int w = 0;
        for (String ln : lines) w = Math.max(w, fm.stringWidth(ln));
        return new Dimension(w, lines.length * fm.getHeight());
    }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        Dimension c = content();
        Insets in = getInsets();
        int cw = fm.charWidth('m');
        int w = Math.max(c.width, (columns > 0 ? columns : 20) * cw);
        int h = Math.max(c.height, rows * fm.getHeight());
        return new Dimension(w + in.left + in.right, h + in.top + in.bottom);
    }
    public Dimension getPreferredScrollableViewportSize() {
        Dimension size = getPreferredSize();
        if (prefSize != null) return size;
        FontMetrics fm = new FontMetrics(getFont());
        Insets in = getInsets();
        if (columns != 0) size.width = columns * fm.charWidth('m') + in.left + in.right;
        if (rows != 0) size.height = rows * fm.getHeight() + in.top + in.bottom;
        return size;
    }
    public int getScrollableUnitIncrement(Rectangle visibleRect, int orientation, int direction) {
        FontMetrics fm = new FontMetrics(getFont());
        return orientation == SwingConstants.VERTICAL ? fm.getHeight() : fm.charWidth('m');
    }
    public int getScrollableBlockIncrement(Rectangle visibleRect, int orientation, int direction) {
        FontMetrics fm = new FontMetrics(getFont());
        if (orientation == SwingConstants.VERTICAL) return Math.max(fm.getHeight(), visibleRect.height - fm.getHeight());
        return visibleRect.width;
    }
    public boolean getScrollableTracksViewportWidth() { return getParent() instanceof JViewport && getParent().getWidth() > getPreferredSize().width; }
    public boolean getScrollableTracksViewportHeight() { return getParent() instanceof JViewport && getParent().getHeight() > getPreferredSize().height; }
    void scrollToCaret() {
        FontMetrics fm = new FontMetrics(getFont());
        int c = Math.min(caret, sb.length());
        int line = 0, ls = 0;
        for (int i = 0; i < c; i++) if (sb.charAt(i) == '\n') { line++; ls = i + 1; }
        Insets in = getInsets();
        int x = in.left + fm.stringWidth(sb.substring(ls, c));
        scrollRectToVisible(new Rectangle(x, in.top + line * fm.getHeight(), 2, fm.getHeight()));
    }
    public void setCaretPosition(int p) { super.setCaretPosition(p); scrollToCaret(); }
    protected void processKeyEvent(KeyEvent e) { super.processKeyEvent(e); if (e.getID() == KeyEvent.KEY_TYPED || e.getID() == KeyEvent.KEY_PRESSED) scrollToCaret(); }
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
