package javax.swing.text;
public class Document {
    private final JTextComponent c;
    public Document(JTextComponent c) { this.c = c; }
    public int getLength() { return c.getText().length(); }
    public String getText(int off, int len) { return c.getText().substring(off, off + len); }
    public void addDocumentListener(javax.swing.event.DocumentListener l) { c.docListeners.add(l); }
    public void removeDocumentListener(javax.swing.event.DocumentListener l) { c.docListeners.remove(l); }
}
