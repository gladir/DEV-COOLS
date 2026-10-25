package javax.swing.event;
import javax.swing.tree.TreePath;
public class TreeExpansionEvent extends java.util.EventObject {
    protected TreePath path;
    public TreeExpansionEvent(Object source, TreePath path) {
        super(source);
        this.path = path;
    }
    public TreePath getPath() { return path; }
}
