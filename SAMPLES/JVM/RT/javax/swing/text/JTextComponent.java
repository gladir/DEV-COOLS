package javax.swing.text;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import java.util.ArrayList;
public abstract class JTextComponent extends JComponent {
    protected StringBuilder sb = new StringBuilder();
    protected int caret;
    protected boolean editable = true;
    protected int selStart = -1, selEnd = -1;
    ArrayList<javax.swing.event.DocumentListener> docListeners = new ArrayList<>();
    public String getText() { return sb.toString(); }
    public void setText(String t) { sb.setLength(0); sb.append(t == null ? "" : t); caret = sb.length(); selStart = selEnd = -1; changed(); }
    public boolean isEditable() { return editable; }
    public void setEditable(boolean b) { editable = b; }
    public int getCaretPosition() { return caret; }
    public void setCaretPosition(int p) { caret = Math.max(0, Math.min(p, sb.length())); repaint(); }
    public void select(int s, int e) { selStart = s; selEnd = e; repaint(); }
    public void selectAll() { selStart = 0; selEnd = sb.length(); repaint(); }
    public String getSelectedText() { return selStart >= 0 && selEnd > selStart ? sb.substring(selStart, selEnd) : null; }
    public void setSelectionStart(int s) { selStart = s; }
    public void setSelectionEnd(int e) { selEnd = e; }
    public void replaceSelection(String s) { if (selStart >= 0 && selEnd > selStart) { sb.delete(selStart, selEnd); caret = selStart; selStart = selEnd = -1; } insert(s); }
    public void copy() { }
    public void cut() { }
    public void paste() { }
    public void setCaretColor(Color c) { }
    public void setSelectionColor(Color c) { }
    public void setMargin(Insets i) { }
    public javax.swing.text.Document getDocument() { return new Document(this); }
    public boolean isMultiLine() { return false; }
    public boolean focusTraversable() { return editable || true; }
    public boolean wantsMouse() { return true; }
    public boolean wantsKeys() { return true; }
    protected void changed() {
        javax.swing.event.DocumentEvent ev = new javax.swing.event.DocumentEvent() { };
        for (javax.swing.event.DocumentListener l : new ArrayList<>(docListeners)) l.changedUpdate(ev);
        repaint();
    }
    protected void insert(String s) {
        if (!editable) return;
        sb.insert(caret, s);
        caret += s.length();
        javax.swing.event.DocumentEvent ev = new javax.swing.event.DocumentEvent() { };
        for (javax.swing.event.DocumentListener l : new ArrayList<>(docListeners)) l.insertUpdate(ev);
        repaint();
    }
    protected void removeRange(int a, int b) {
        if (!editable || a >= b) return;
        sb.delete(a, b);
        javax.swing.event.DocumentEvent ev = new javax.swing.event.DocumentEvent() { };
        for (javax.swing.event.DocumentListener l : new ArrayList<>(docListeners)) l.removeUpdate(ev);
        repaint();
    }
    protected void processKeyEvent(KeyEvent e) {
        super.processKeyEvent(e);
        if (e.isConsumed()) return;
        if (e.getID() == KeyEvent.KEY_TYPED) {
            char c = e.getKeyChar();
            if (c >= 32 && c != 127) { replaceSelection(String.valueOf(c)); }
            else if (c == '\b') { if (selStart >= 0 && selEnd > selStart) replaceSelection(""); else if (caret > 0) { removeRange(caret - 1, caret); caret--; } }
            else if (c == '\n') enter();
        } else if (e.getID() == KeyEvent.KEY_PRESSED) {
            switch (e.getKeyCode()) {
                case KeyEvent.VK_LEFT: if (caret > 0) caret--; selStart = selEnd = -1; repaint(); break;
                case KeyEvent.VK_RIGHT: if (caret < sb.length()) caret++; selStart = selEnd = -1; repaint(); break;
                case KeyEvent.VK_HOME: caret = lineStart(); repaint(); break;
                case KeyEvent.VK_END: caret = lineEnd(); repaint(); break;
                case KeyEvent.VK_DELETE: if (caret < sb.length()) removeRange(caret, caret + 1); break;
                case KeyEvent.VK_UP: up(); break;
                case KeyEvent.VK_DOWN: down(); break;
            }
        }
    }
    protected int lineStart() { return 0; }
    protected int lineEnd() { return sb.length(); }
    protected void up() { }
    protected void down() { }
    protected void enter() { }
}
