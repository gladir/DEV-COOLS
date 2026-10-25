package javax.swing.tree;
import javax.swing.event.TreeModelListener;
public interface TreeModel {
    Object getRoot();
    Object getChild(Object parent, int index);
    int getChildCount(Object parent);
    boolean isLeaf(Object node);
    void valueForPathChanged(TreePath path, Object newValue);
    int getIndexOfChild(Object parent, Object child);
    void addTreeModelListener(TreeModelListener l);
    void removeTreeModelListener(TreeModelListener l);
}
