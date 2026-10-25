package javax.swing.tree;
import javax.swing.event.TreeExpansionEvent;
public class ExpandVetoException extends Exception {
    protected TreeExpansionEvent event;
    public ExpandVetoException(TreeExpansionEvent event) { this(event, null); }
    public ExpandVetoException(TreeExpansionEvent event, String message) { super(message); this.event = event; }
}
