package javax.swing.tree;
import java.io.Serializable;
import java.util.EventListener;
import javax.swing.event.*;
public class DefaultTreeModel implements Serializable, TreeModel {
    protected TreeNode root;
    protected EventListenerList listenerList = new EventListenerList();
    protected boolean asksAllowsChildren;
    public DefaultTreeModel(TreeNode root) { this(root, false); }
    public DefaultTreeModel(TreeNode root, boolean asksAllowsChildren) {
        super();
        this.root = root;
        this.asksAllowsChildren = asksAllowsChildren;
    }
    public void setAsksAllowsChildren(boolean newValue) { asksAllowsChildren = newValue; }
    public boolean asksAllowsChildren() { return asksAllowsChildren; }
    public void setRoot(TreeNode root) {
        Object oldRoot = this.root;
        this.root = root;
        if (root == null && oldRoot != null) fireTreeStructureChanged(this, null);
        else nodeStructureChanged(root);
    }
    public Object getRoot() { return root; }
    public int getIndexOfChild(Object parent, Object child) {
        if (parent == null || child == null) return -1;
        return ((TreeNode) parent).getIndex((TreeNode) child);
    }
    public Object getChild(Object parent, int index) { return ((TreeNode) parent).getChildAt(index); }
    public int getChildCount(Object parent) { return ((TreeNode) parent).getChildCount(); }
    public boolean isLeaf(Object node) {
        if (asksAllowsChildren) return !((TreeNode) node).getAllowsChildren();
        return ((TreeNode) node).isLeaf();
    }
    public void reload() { reload(root); }
    public void valueForPathChanged(TreePath path, Object newValue) {
        MutableTreeNode aNode = (MutableTreeNode) path.getLastPathComponent();
        aNode.setUserObject(newValue);
        nodeChanged(aNode);
    }
    public void insertNodeInto(MutableTreeNode newChild, MutableTreeNode parent, int index) {
        parent.insert(newChild, index);
        int[] newIndexs = new int[1];
        newIndexs[0] = index;
        nodesWereInserted(parent, newIndexs);
    }
    public void removeNodeFromParent(MutableTreeNode node) {
        MutableTreeNode parent = (MutableTreeNode) node.getParent();
        if (parent == null) throw new IllegalArgumentException("node does not have a parent.");
        int[] childIndex = new int[1];
        Object[] removedArray = new Object[1];
        childIndex[0] = parent.getIndex(node);
        parent.remove(childIndex[0]);
        removedArray[0] = node;
        nodesWereRemoved(parent, childIndex, removedArray);
    }
    public void nodeChanged(TreeNode node) {
        if (listenerList != null && node != null) {
            TreeNode parent = node.getParent();
            if (parent != null) {
                int anIndex = parent.getIndex(node);
                if (anIndex != -1) {
                    int[] cIndexs = new int[1];
                    cIndexs[0] = anIndex;
                    nodesChanged(parent, cIndexs);
                }
            } else if (node == getRoot()) {
                nodesChanged(node, null);
            }
        }
    }
    public void reload(TreeNode node) {
        if (node != null) fireTreeStructureChanged(this, getPathToRoot(node), null, null);
    }
    public void nodesWereInserted(TreeNode node, int[] childIndices) {
        if (listenerList != null && node != null && childIndices != null && childIndices.length > 0) {
            int cCount = childIndices.length;
            Object[] newChildren = new Object[cCount];
            for (int counter = 0; counter < cCount; counter++) newChildren[counter] = node.getChildAt(childIndices[counter]);
            fireTreeNodesInserted(this, getPathToRoot(node), childIndices, newChildren);
        }
    }
    public void nodesWereRemoved(TreeNode node, int[] childIndices, Object[] removedChildren) {
        if (node != null && childIndices != null) fireTreeNodesRemoved(this, getPathToRoot(node), childIndices, removedChildren);
    }
    public void nodesChanged(TreeNode node, int[] childIndices) {
        if (node != null) {
            if (childIndices != null) {
                int cCount = childIndices.length;
                if (cCount > 0) {
                    Object[] cChildren = new Object[cCount];
                    for (int counter = 0; counter < cCount; counter++) cChildren[counter] = node.getChildAt(childIndices[counter]);
                    fireTreeNodesChanged(this, getPathToRoot(node), childIndices, cChildren);
                }
            } else if (node == getRoot()) {
                fireTreeNodesChanged(this, getPathToRoot(node), null, null);
            }
        }
    }
    public void nodeStructureChanged(TreeNode node) {
        if (node != null) fireTreeStructureChanged(this, getPathToRoot(node), null, null);
    }
    public TreeNode[] getPathToRoot(TreeNode aNode) { return getPathToRoot(aNode, 0); }
    protected TreeNode[] getPathToRoot(TreeNode aNode, int depth) {
        TreeNode[] retNodes;
        if (aNode == null) {
            if (depth == 0) return null;
            else retNodes = new TreeNode[depth];
        } else {
            depth++;
            if (aNode == root) retNodes = new TreeNode[depth];
            else retNodes = getPathToRoot(aNode.getParent(), depth);
            retNodes[retNodes.length - depth] = aNode;
        }
        return retNodes;
    }
    public void addTreeModelListener(TreeModelListener l) { listenerList.add(TreeModelListener.class, l); }
    public void removeTreeModelListener(TreeModelListener l) { listenerList.remove(TreeModelListener.class, l); }
    public TreeModelListener[] getTreeModelListeners() { return listenerList.getListeners(TreeModelListener.class); }
    protected void fireTreeNodesChanged(Object source, Object[] path, int[] childIndices, Object[] children) {
        Object[] listeners = listenerList.getListenerList();
        TreeModelEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeModelListener.class) {
                if (e == null) e = new TreeModelEvent(source, path, childIndices, children);
                ((TreeModelListener) listeners[i + 1]).treeNodesChanged(e);
            }
        }
    }
    protected void fireTreeNodesInserted(Object source, Object[] path, int[] childIndices, Object[] children) {
        Object[] listeners = listenerList.getListenerList();
        TreeModelEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeModelListener.class) {
                if (e == null) e = new TreeModelEvent(source, path, childIndices, children);
                ((TreeModelListener) listeners[i + 1]).treeNodesInserted(e);
            }
        }
    }
    protected void fireTreeNodesRemoved(Object source, Object[] path, int[] childIndices, Object[] children) {
        Object[] listeners = listenerList.getListenerList();
        TreeModelEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeModelListener.class) {
                if (e == null) e = new TreeModelEvent(source, path, childIndices, children);
                ((TreeModelListener) listeners[i + 1]).treeNodesRemoved(e);
            }
        }
    }
    protected void fireTreeStructureChanged(Object source, Object[] path, int[] childIndices, Object[] children) {
        Object[] listeners = listenerList.getListenerList();
        TreeModelEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeModelListener.class) {
                if (e == null) e = new TreeModelEvent(source, path, childIndices, children);
                ((TreeModelListener) listeners[i + 1]).treeStructureChanged(e);
            }
        }
    }
    private void fireTreeStructureChanged(Object source, TreePath path) {
        Object[] listeners = listenerList.getListenerList();
        TreeModelEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeModelListener.class) {
                if (e == null) e = new TreeModelEvent(source, path);
                ((TreeModelListener) listeners[i + 1]).treeStructureChanged(e);
            }
        }
    }
    public <T extends EventListener> T[] getListeners(Class<T> listenerType) { return listenerList.getListeners(listenerType); }
}
