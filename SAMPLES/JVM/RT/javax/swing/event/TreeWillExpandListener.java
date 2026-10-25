package javax.swing.event;
import javax.swing.tree.ExpandVetoException;
public interface TreeWillExpandListener extends java.util.EventListener {
    void treeWillExpand(TreeExpansionEvent event) throws ExpandVetoException;
    void treeWillCollapse(TreeExpansionEvent event) throws ExpandVetoException;
}
