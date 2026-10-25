package javax.swing.event;
import javax.swing.tree.TreePath;
public class TreeModelEvent extends java.util.EventObject {
    protected TreePath path;
    protected int[] childIndices;
    protected Object[] children;
    public TreeModelEvent(Object source, Object[] path, int[] childIndices, Object[] children) {
        this(source, path == null ? null : new TreePath(path), childIndices, children);
    }
    public TreeModelEvent(Object source, TreePath path, int[] childIndices, Object[] children) {
        super(source);
        this.path = path;
        this.childIndices = childIndices;
        this.children = children;
    }
    public TreeModelEvent(Object source, Object[] path) { this(source, path == null ? null : new TreePath(path)); }
    public TreeModelEvent(Object source, TreePath path) {
        super(source);
        this.path = path;
        this.childIndices = new int[0];
    }
    public TreePath getTreePath() { return path; }
    public Object[] getPath() { return path != null ? path.getPath() : null; }
    public Object[] getChildren() {
        if (children != null) {
            int cCount = children.length;
            Object[] retChildren = new Object[cCount];
            System.arraycopy(children, 0, retChildren, 0, cCount);
            return retChildren;
        }
        return null;
    }
    public int[] getChildIndices() {
        if (childIndices != null) {
            int cCount = childIndices.length;
            int[] retArray = new int[cCount];
            System.arraycopy(childIndices, 0, retArray, 0, cCount);
            return retArray;
        }
        return null;
    }
    public String toString() {
        StringBuilder retBuffer = new StringBuilder();
        retBuffer.append(getClass().getName() + " " + Integer.toString(hashCode()));
        if (path != null) retBuffer.append(" path " + path);
        if (childIndices != null) {
            retBuffer.append(" indices [ ");
            for (int counter = 0; counter < childIndices.length; counter++) retBuffer.append(Integer.toString(childIndices[counter]) + " ");
            retBuffer.append("]");
        }
        if (children != null) {
            retBuffer.append(" children [ ");
            for (int counter = 0; counter < children.length; counter++) retBuffer.append(children[counter] + " ");
            retBuffer.append("]");
        }
        return retBuffer.toString();
    }
}
