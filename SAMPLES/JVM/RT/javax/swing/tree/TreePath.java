package javax.swing.tree;
public class TreePath implements java.io.Serializable {
    private TreePath parentPath;
    private Object lastPathComponent;
    public TreePath(Object[] path) {
        if (path == null || path.length == 0) throw new IllegalArgumentException("path in TreePath must be non null and not empty.");
        lastPathComponent = path[path.length - 1];
        if (lastPathComponent == null) throw new IllegalArgumentException("Last path component must be non-null");
        if (path.length > 1) parentPath = new TreePath(path, path.length - 1);
    }
    public TreePath(Object lastPathComponent) {
        if (lastPathComponent == null) throw new IllegalArgumentException("path in TreePath must be non null.");
        this.lastPathComponent = lastPathComponent;
        parentPath = null;
    }
    protected TreePath(TreePath parent, Object lastPathComponent) {
        if (lastPathComponent == null) throw new IllegalArgumentException("path in TreePath must be non null.");
        parentPath = parent;
        this.lastPathComponent = lastPathComponent;
    }
    protected TreePath(Object[] path, int length) {
        lastPathComponent = path[length - 1];
        if (lastPathComponent == null) throw new IllegalArgumentException("Path elements must be non-null");
        if (length > 1) parentPath = new TreePath(path, length - 1);
    }
    protected TreePath() { }
    public Object[] getPath() {
        int i = getPathCount();
        Object[] result = new Object[i--];
        for (TreePath path = this; path != null; path = path.parentPath) result[i--] = path.lastPathComponent;
        return result;
    }
    public Object getLastPathComponent() { return lastPathComponent; }
    public int getPathCount() {
        int result = 0;
        for (TreePath path = this; path != null; path = path.parentPath) result++;
        return result;
    }
    public Object getPathComponent(int index) {
        int pathLength = getPathCount();
        if (index < 0 || index >= pathLength) throw new IllegalArgumentException("Index " + index + " is out of the specified range");
        TreePath path = this;
        for (int i = pathLength - 1; i != index; i--) path = path.parentPath;
        return path.lastPathComponent;
    }
    public boolean equals(Object o) {
        if (o == this) return true;
        if (o instanceof TreePath) {
            TreePath oTreePath = (TreePath) o;
            if (getPathCount() != oTreePath.getPathCount()) return false;
            for (TreePath path = this; path != null; path = path.parentPath) {
                if (!(path.lastPathComponent.equals(oTreePath.lastPathComponent))) return false;
                oTreePath = oTreePath.parentPath;
            }
            return true;
        }
        return false;
    }
    public int hashCode() { return lastPathComponent.hashCode(); }
    public boolean isDescendant(TreePath aTreePath) {
        if (aTreePath == this) return true;
        if (aTreePath != null) {
            int pathLength = getPathCount();
            int oPathLength = aTreePath.getPathCount();
            if (oPathLength < pathLength) return false;
            while (oPathLength-- > pathLength) aTreePath = aTreePath.getParentPath();
            return equals(aTreePath);
        }
        return false;
    }
    public TreePath pathByAddingChild(Object child) {
        if (child == null) throw new NullPointerException("Null child not allowed");
        return new TreePath(this, child);
    }
    public TreePath getParentPath() { return parentPath; }
    public String toString() {
        StringBuilder tempSpot = new StringBuilder("[");
        for (int counter = 0, maxCounter = getPathCount(); counter < maxCounter; counter++) {
            if (counter > 0) tempSpot.append(", ");
            tempSpot.append(getPathComponent(counter));
        }
        tempSpot.append("]");
        return tempSpot.toString();
    }
}
