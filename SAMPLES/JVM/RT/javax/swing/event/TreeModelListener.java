package javax.swing.event;
public interface TreeModelListener extends java.util.EventListener {
    void treeNodesChanged(TreeModelEvent e);
    void treeNodesInserted(TreeModelEvent e);
    void treeNodesRemoved(TreeModelEvent e);
    void treeStructureChanged(TreeModelEvent e);
}
