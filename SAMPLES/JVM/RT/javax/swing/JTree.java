package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import javax.swing.event.*;
import javax.swing.tree.*;
public class JTree extends JComponent implements Scrollable {
    public static final String CELL_RENDERER_PROPERTY = "cellRenderer";
    public static final String TREE_MODEL_PROPERTY = "model";
    public static final String ROOT_VISIBLE_PROPERTY = "rootVisible";
    public static final String SHOWS_ROOT_HANDLES_PROPERTY = "showsRootHandles";
    public static final String ROW_HEIGHT_PROPERTY = "rowHeight";
    public static final String CELL_EDITOR_PROPERTY = "cellEditor";
    public static final String EDITABLE_PROPERTY = "editable";
    public static final String LARGE_MODEL_PROPERTY = "largeModel";
    public static final String SELECTION_MODEL_PROPERTY = "selectionModel";
    public static final String VISIBLE_ROW_COUNT_PROPERTY = "visibleRowCount";
    public static final String INVOKES_STOP_CELL_EDITING_PROPERTY = "invokesStopCellEditing";
    public static final String SCROLLS_ON_EXPAND_PROPERTY = "scrollsOnExpand";
    public static final String TOGGLE_CLICK_COUNT_PROPERTY = "toggleClickCount";
    public static final String LEAD_SELECTION_PATH_PROPERTY = "leadSelectionPath";
    public static final String ANCHOR_SELECTION_PATH_PROPERTY = "anchorSelectionPath";
    public static final String EXPANDS_SELECTED_PATHS_PROPERTY = "expandsSelectedPaths";
    protected transient TreeModel treeModel;
    protected transient TreeSelectionModel selectionModel;
    protected boolean rootVisible;
    protected transient TreeCellRenderer cellRenderer;
    protected int rowHeight;
    private transient Hashtable<TreePath, Boolean> expandedState;
    protected boolean showsRootHandles;
    protected transient TreeSelectionRedirector selectionRedirector;
    protected transient TreeCellEditor cellEditor;
    protected boolean editable;
    protected boolean largeModel;
    protected int visibleRowCount;
    protected boolean invokesStopCellEditing;
    protected boolean scrollsOnExpand;
    protected int toggleClickCount;
    protected transient TreeModelListener treeModelListener;
    protected EventListenerList listenerList = new EventListenerList();
    private TreePath leadPath, anchorPath;
    private boolean expandsSelectedPaths;
    // etat interne (equivalent de l'interface utilisateur)
    private static final int LEFT_INDENT = 7, RIGHT_INDENT = 13;
    private final DefaultTreeCellRenderer defaultRenderer = new DefaultTreeCellRenderer();
    private ArrayList<TreePath> rowList = new ArrayList<>();
    private HashMap<TreePath, Integer> rowIndex = new HashMap<>();
    private boolean rowsValid;
    private int[] rowYs = new int[1], rowWs = new int[0], rowHs = new int[0];
    private boolean sizesValid;
    private int maxExtent;
    private Component editingComponent;
    private TreePath editingPath;
    private KeyListener editorKeys;
    private javax.swing.Timer editTimer;
    private TreePath editTimerPath;
    private String typed = "";
    private long typedAt;
    private final RowMapper rowMapper = new RowMapper() {
        public int[] getRowsForPaths(TreePath[] paths) {
            if (paths == null) return null;
            int[] rows = new int[paths.length];
            for (int i = 0; i < paths.length; i++) rows[i] = getRowForPath(paths[i]);
            return rows;
        }
    };
    private final TreeSelectionListener uiSelectionListener = new TreeSelectionListener() {
        public void valueChanged(TreeSelectionEvent event) {
            completeEditing();
            if (editTimer != null) editTimer.stop();
            if (getExpandsSelectedPaths() && selectionModel != null) {
                TreePath[] paths = selectionModel.getSelectionPaths();
                if (paths != null) {
                    for (int counter = paths.length - 1; counter >= 0; counter--) {
                        TreePath path = paths[counter].getParentPath();
                        boolean expand = true;
                        while (path != null) {
                            if (treeModel.isLeaf(path.getLastPathComponent())) { expand = false; path = null; }
                            else path = path.getParentPath();
                        }
                        if (expand) makeVisible(paths[counter]);
                    }
                }
            }
            TreePath lead = selectionModel.getLeadSelectionPath();
            setAnchorSelectionPath(lead);
            setLeadSelectionPath(lead);
            repaint();
        }
    };
    protected static TreeModel getDefaultTreeModel() {
        DefaultMutableTreeNode root = new DefaultMutableTreeNode("JTree");
        DefaultMutableTreeNode parent;
        parent = new DefaultMutableTreeNode("colors");
        root.add(parent);
        parent.add(new DefaultMutableTreeNode("blue"));
        parent.add(new DefaultMutableTreeNode("violet"));
        parent.add(new DefaultMutableTreeNode("red"));
        parent.add(new DefaultMutableTreeNode("yellow"));
        parent = new DefaultMutableTreeNode("sports");
        root.add(parent);
        parent.add(new DefaultMutableTreeNode("basketball"));
        parent.add(new DefaultMutableTreeNode("soccer"));
        parent.add(new DefaultMutableTreeNode("football"));
        parent.add(new DefaultMutableTreeNode("hockey"));
        parent = new DefaultMutableTreeNode("food");
        root.add(parent);
        parent.add(new DefaultMutableTreeNode("hot dogs"));
        parent.add(new DefaultMutableTreeNode("pizza"));
        parent.add(new DefaultMutableTreeNode("ravioli"));
        parent.add(new DefaultMutableTreeNode("bananas"));
        return new DefaultTreeModel(root);
    }
    protected static TreeModel createTreeModel(Object value) {
        DefaultMutableTreeNode root;
        if ((value instanceof Object[]) || (value instanceof Hashtable) || (value instanceof Vector)) {
            root = new DefaultMutableTreeNode("root");
            DynamicUtilTreeNode.createChildren(root, value);
        } else {
            root = new DynamicUtilTreeNode("root", value);
        }
        return new DefaultTreeModel(root, false);
    }
    public JTree() { this(getDefaultTreeModel()); }
    public JTree(Object[] value) {
        this(createTreeModel(value));
        this.setRootVisible(false);
        this.setShowsRootHandles(true);
        expandRoot();
    }
    public JTree(Vector<?> value) {
        this(createTreeModel(value));
        this.setRootVisible(false);
        this.setShowsRootHandles(true);
        expandRoot();
    }
    public JTree(Hashtable<?, ?> value) {
        this(createTreeModel(value));
        this.setRootVisible(false);
        this.setShowsRootHandles(true);
        expandRoot();
    }
    public JTree(TreeNode root) { this(root, false); }
    public JTree(TreeNode root, boolean asksAllowsChildren) { this(new DefaultTreeModel(root, asksAllowsChildren)); }
    public JTree(TreeModel newModel) {
        super();
        toggleClickCount = 2;
        expandedState = new Hashtable<TreePath, Boolean>();
        rowHeight = 0;
        visibleRowCount = 20;
        rootVisible = true;
        selectionModel = new DefaultTreeSelectionModel();
        selectionModel.setRowMapper(rowMapper);
        selectionModel.addTreeSelectionListener(uiSelectionListener);
        cellRenderer = defaultRenderer;
        scrollsOnExpand = true;
        expandsSelectedPaths = true;
        opaque = true;
        background = Color.WHITE;
        foreground = new Color(51, 51, 51);
        setModel(newModel);
    }
    public TreeCellRenderer getCellRenderer() { return cellRenderer; }
    public void setCellRenderer(TreeCellRenderer x) {
        TreeCellRenderer oldValue = cellRenderer;
        cellRenderer = x;
        firePropertyChange(CELL_RENDERER_PROPERTY, oldValue, cellRenderer);
        invalidateRows();
        revalidate();
        repaint();
    }
    public void setEditable(boolean flag) {
        boolean oldValue = this.editable;
        this.editable = flag;
        if (flag && cellEditor == null) setCellEditor(new DefaultTreeCellEditor(this, defaultRenderer));
        firePropertyChange(EDITABLE_PROPERTY, oldValue, flag);
    }
    public boolean isEditable() { return editable; }
    public void setCellEditor(TreeCellEditor cellEditor) {
        TreeCellEditor oldEditor = this.cellEditor;
        if (oldEditor != null) oldEditor.removeCellEditorListener(editorListener);
        this.cellEditor = cellEditor;
        if (cellEditor != null) cellEditor.addCellEditorListener(editorListener);
        firePropertyChange(CELL_EDITOR_PROPERTY, oldEditor, cellEditor);
    }
    public TreeCellEditor getCellEditor() { return cellEditor; }
    public TreeModel getModel() { return treeModel; }
    public void setModel(TreeModel newModel) {
        clearSelection();
        TreeModel oldModel = treeModel;
        if (treeModel != null && treeModelListener != null) treeModel.removeTreeModelListener(treeModelListener);
        treeModel = newModel;
        clearToggledPaths();
        if (treeModel != null) {
            if (treeModelListener == null) treeModelListener = createTreeModelListener();
            if (treeModelListener != null) treeModel.addTreeModelListener(treeModelListener);
            Object treeRoot = treeModel.getRoot();
            if (treeRoot != null && !treeModel.isLeaf(treeRoot)) expandedState.put(new TreePath(treeRoot), Boolean.TRUE);
        }
        invalidateRows();
        firePropertyChange(TREE_MODEL_PROPERTY, oldModel, treeModel);
        revalidate();
        repaint();
    }
    public boolean isRootVisible() { return rootVisible; }
    public void setRootVisible(boolean rootVisible) {
        boolean oldValue = this.rootVisible;
        this.rootVisible = rootVisible;
        invalidateRows();
        firePropertyChange(ROOT_VISIBLE_PROPERTY, oldValue, this.rootVisible);
        revalidate();
        repaint();
    }
    public void setShowsRootHandles(boolean newValue) {
        boolean oldValue = showsRootHandles;
        showsRootHandles = newValue;
        invalidateRows();
        firePropertyChange(SHOWS_ROOT_HANDLES_PROPERTY, oldValue, showsRootHandles);
        revalidate();
        repaint();
    }
    public boolean getShowsRootHandles() { return showsRootHandles; }
    public void setRowHeight(int rowHeight) {
        int oldValue = this.rowHeight;
        this.rowHeight = rowHeight;
        invalidateRows();
        firePropertyChange(ROW_HEIGHT_PROPERTY, oldValue, rowHeight);
        revalidate();
        repaint();
    }
    public int getRowHeight() { return rowHeight; }
    public boolean isFixedRowHeight() { return rowHeight > 0; }
    public void setLargeModel(boolean newValue) { boolean oldValue = largeModel; largeModel = newValue; firePropertyChange(LARGE_MODEL_PROPERTY, oldValue, newValue); }
    public boolean isLargeModel() { return largeModel; }
    public void setInvokesStopCellEditing(boolean newValue) { boolean old = invokesStopCellEditing; invokesStopCellEditing = newValue; firePropertyChange(INVOKES_STOP_CELL_EDITING_PROPERTY, old, newValue); }
    public boolean getInvokesStopCellEditing() { return invokesStopCellEditing; }
    public void setScrollsOnExpand(boolean newValue) { boolean old = scrollsOnExpand; scrollsOnExpand = newValue; firePropertyChange(SCROLLS_ON_EXPAND_PROPERTY, old, newValue); }
    public boolean getScrollsOnExpand() { return scrollsOnExpand; }
    public void setToggleClickCount(int clickCount) { int old = toggleClickCount; toggleClickCount = clickCount; firePropertyChange(TOGGLE_CLICK_COUNT_PROPERTY, old, clickCount); }
    public int getToggleClickCount() { return toggleClickCount; }
    public void setExpandsSelectedPaths(boolean newValue) { boolean old = expandsSelectedPaths; expandsSelectedPaths = newValue; firePropertyChange(EXPANDS_SELECTED_PATHS_PROPERTY, old, newValue); }
    public boolean getExpandsSelectedPaths() { return expandsSelectedPaths; }
    public void setDragEnabled(boolean b) { }
    public boolean getDragEnabled() { return false; }
    public boolean isPathEditable(TreePath path) { return isEditable(); }
    public String getToolTipText(MouseEvent event) {
        if (event != null) {
            Point p = event.getPoint();
            int selRow = getRowForLocation(p.x, p.y);
            TreeCellRenderer r = getCellRenderer();
            if (selRow != -1 && r != null) {
                TreePath path = getPathForRow(selRow);
                Object lastPath = path.getLastPathComponent();
                Component rComponent = r.getTreeCellRendererComponent(this, lastPath, isRowSelected(selRow), isExpanded(selRow), getModel().isLeaf(lastPath), selRow, true);
                if (rComponent instanceof JComponent) return ((JComponent) rComponent).getToolTipText();
            }
        }
        return getToolTipText();
    }
    public String convertValueToText(Object value, boolean selected, boolean expanded, boolean leaf, int row, boolean hasFocus) {
        if (value != null) {
            String sValue = value.toString();
            if (sValue != null) return sValue;
        }
        return "";
    }
    public int getRowCount() { ensureRows(); return rowList.size(); }
    // ---- selection ----
    public void setSelectionPath(TreePath path) { getSelectionModel().setSelectionPath(path); }
    public void setSelectionPaths(TreePath[] paths) { getSelectionModel().setSelectionPaths(paths); }
    public void setLeadSelectionPath(TreePath newPath) {
        TreePath oldValue = leadPath;
        leadPath = newPath;
        firePropertyChange(LEAD_SELECTION_PATH_PROPERTY, oldValue, newPath);
    }
    public void setAnchorSelectionPath(TreePath newPath) {
        TreePath oldValue = anchorPath;
        anchorPath = newPath;
        firePropertyChange(ANCHOR_SELECTION_PATH_PROPERTY, oldValue, newPath);
    }
    public void setSelectionRow(int row) { setSelectionRows(new int[] { row }); }
    public void setSelectionRows(int[] rows) {
        if (rows != null) {
            int numRows = rows.length;
            TreePath[] paths = new TreePath[numRows];
            for (int counter = 0; counter < numRows; counter++) paths[counter] = getPathForRow(rows[counter]);
            setSelectionPaths(paths);
        }
    }
    public void addSelectionPath(TreePath path) { getSelectionModel().addSelectionPath(path); }
    public void addSelectionPaths(TreePath[] paths) { getSelectionModel().addSelectionPaths(paths); }
    public void addSelectionRow(int row) { addSelectionRows(new int[] { row }); }
    public void addSelectionRows(int[] rows) {
        if (rows != null) {
            int numRows = rows.length;
            TreePath[] paths = new TreePath[numRows];
            for (int counter = 0; counter < numRows; counter++) paths[counter] = getPathForRow(rows[counter]);
            addSelectionPaths(paths);
        }
    }
    public Object getLastSelectedPathComponent() {
        TreePath selPath = getSelectionModel().getSelectionPath();
        if (selPath != null) return selPath.getLastPathComponent();
        return null;
    }
    public TreePath getLeadSelectionPath() { return leadPath; }
    public TreePath getAnchorSelectionPath() { return anchorPath; }
    public TreePath getSelectionPath() { return getSelectionModel().getSelectionPath(); }
    public TreePath[] getSelectionPaths() {
        TreePath[] selectionPaths = getSelectionModel().getSelectionPaths();
        return (selectionPaths != null && selectionPaths.length > 0) ? selectionPaths : null;
    }
    public int[] getSelectionRows() { return getSelectionModel().getSelectionRows(); }
    public int getSelectionCount() { return selectionModel.getSelectionCount(); }
    public int getMinSelectionRow() { return getSelectionModel().getMinSelectionRow(); }
    public int getMaxSelectionRow() { return getSelectionModel().getMaxSelectionRow(); }
    public int getLeadSelectionRow() {
        TreePath leadPath = getLeadSelectionPath();
        if (leadPath != null) return getRowForPath(leadPath);
        return -1;
    }
    public boolean isPathSelected(TreePath path) { return getSelectionModel().isPathSelected(path); }
    public boolean isRowSelected(int row) { return getSelectionModel().isRowSelected(row); }
    public Enumeration<TreePath> getExpandedDescendants(TreePath parent) {
        if (!isExpanded(parent)) return null;
        Enumeration<TreePath> toggledPaths = expandedState.keys();
        Vector<TreePath> elements = null;
        while (toggledPaths.hasMoreElements()) {
            TreePath path = toggledPaths.nextElement();
            Boolean value = expandedState.get(path);
            if (path != parent && value != null && value && parent.isDescendant(path) && isVisible(path)) {
                if (elements == null) elements = new Vector<TreePath>();
                elements.addElement(path);
            }
        }
        if (elements == null) {
            Set<TreePath> empty = Collections.emptySet();
            return Collections.enumeration(empty);
        }
        return elements.elements();
    }
    public boolean hasBeenExpanded(TreePath path) { return (path != null && expandedState.get(path) != null); }
    public boolean isExpanded(TreePath path) {
        if (path == null) return false;
        Boolean value;
        do {
            value = expandedState.get(path);
            if (value == null || !value) return false;
        } while ((path = path.getParentPath()) != null);
        return true;
    }
    public boolean isExpanded(int row) {
        TreePath path = getPathForRow(row);
        if (path != null) {
            Boolean value = expandedState.get(path);
            return (value != null && value);
        }
        return false;
    }
    public boolean isCollapsed(TreePath path) { return !isExpanded(path); }
    public boolean isCollapsed(int row) { return !isExpanded(row); }
    public void makeVisible(TreePath path) {
        if (path != null) {
            TreePath parentPath = path.getParentPath();
            if (parentPath != null) expandPath(parentPath);
        }
    }
    public boolean isVisible(TreePath path) {
        if (path != null) {
            TreePath parentPath = path.getParentPath();
            if (parentPath != null) return isExpanded(parentPath);
            return true;
        }
        return false;
    }
    public Rectangle getPathBounds(TreePath path) {
        int row = getRowForPath(path);
        if (row < 0) return null;
        ensureSizes();
        Insets in = getInsets();
        return new Rectangle(in.left + rowX(path), in.top + rowYs[row], rowWs[row], rowHs[row]);
    }
    public Rectangle getRowBounds(int row) { return getPathBounds(getPathForRow(row)); }
    public void scrollPathToVisible(TreePath path) {
        if (path != null) {
            makeVisible(path);
            Rectangle bounds = getPathBounds(path);
            if (bounds != null) scrollRectToVisible(bounds);
        }
    }
    public void scrollRowToVisible(int row) { scrollPathToVisible(getPathForRow(row)); }
    public TreePath getPathForRow(int row) {
        ensureRows();
        if (row < 0 || row >= rowList.size()) return null;
        return rowList.get(row);
    }
    public int getRowForPath(TreePath path) {
        if (path == null) return -1;
        ensureRows();
        Integer i = rowIndex.get(path);
        return i == null ? -1 : i.intValue();
    }
    public void expandPath(TreePath path) {
        TreeModel model = getModel();
        if (path != null && model != null && !model.isLeaf(path.getLastPathComponent())) setExpandedState(path, true);
    }
    public void expandRow(int row) { expandPath(getPathForRow(row)); }
    public void collapsePath(TreePath path) { setExpandedState(path, false); }
    public void collapseRow(int row) { collapsePath(getPathForRow(row)); }
    public TreePath getPathForLocation(int x, int y) {
        TreePath closestPath = getClosestPathForLocation(x, y);
        if (closestPath != null) {
            Rectangle pathBounds = getPathBounds(closestPath);
            if (pathBounds != null && x >= pathBounds.x && x < (pathBounds.x + pathBounds.width) && y >= pathBounds.y && y < (pathBounds.y + pathBounds.height))
                return closestPath;
        }
        return null;
    }
    public int getRowForLocation(int x, int y) { return getRowForPath(getPathForLocation(x, y)); }
    public TreePath getClosestPathForLocation(int x, int y) {
        ensureSizes();
        int n = rowList.size();
        if (n == 0) return null;
        int yy = y - getInsets().top;
        if (yy < 0) return rowList.get(0);
        if (yy >= rowYs[n]) return rowList.get(n - 1);
        return rowList.get(rowAtY(yy));
    }
    public int getClosestRowForLocation(int x, int y) { return getRowForPath(getClosestPathForLocation(x, y)); }
    public boolean isEditing() { return editingComponent != null; }
    public boolean stopEditing() {
        if (editingComponent != null && cellEditor != null) {
            if (cellEditor.stopCellEditing()) return true;
            return false;
        }
        return false;
    }
    public void cancelEditing() {
        if (editingComponent != null && cellEditor != null) cellEditor.cancelCellEditing();
    }
    public void startEditingAtPath(TreePath path) {
        if (path == null) return;
        scrollPathToVisible(path);
        startEditing(path, null);
    }
    public TreePath getEditingPath() { return editingPath; }
    public void setSelectionModel(TreeSelectionModel selectionModel) {
        if (selectionModel == null) selectionModel = EmptySelectionModel.sharedInstance();
        TreeSelectionModel oldValue = this.selectionModel;
        if (this.selectionModel != null) {
            this.selectionModel.removeTreeSelectionListener(uiSelectionListener);
            if (selectionRedirector != null) this.selectionModel.removeTreeSelectionListener(selectionRedirector);
        }
        this.selectionModel = selectionModel;
        selectionModel.setRowMapper(rowMapper);
        selectionModel.addTreeSelectionListener(uiSelectionListener);
        if (selectionRedirector != null) this.selectionModel.addTreeSelectionListener(selectionRedirector);
        firePropertyChange(SELECTION_MODEL_PROPERTY, oldValue, this.selectionModel);
        repaint();
    }
    public TreeSelectionModel getSelectionModel() { return selectionModel; }
    protected TreePath[] getPathBetweenRows(int index0, int index1) {
        int rowCount = getRowCount();
        if (rowCount > 0 && !((index0 < 0 && index1 < 0) || (index0 >= rowCount && index1 >= rowCount))) {
            index0 = Math.min(rowCount - 1, Math.max(index0, 0));
            index1 = Math.min(rowCount - 1, Math.max(index1, 0));
            int minIndex = Math.min(index0, index1);
            int maxIndex = Math.max(index0, index1);
            TreePath[] selection = new TreePath[maxIndex - minIndex + 1];
            for (int counter = minIndex; counter <= maxIndex; counter++) selection[counter - minIndex] = getPathForRow(counter);
            return selection;
        }
        return new TreePath[0];
    }
    public void setSelectionInterval(int index0, int index1) { getSelectionModel().setSelectionPaths(getPathBetweenRows(index0, index1)); }
    public void addSelectionInterval(int index0, int index1) {
        TreePath[] paths = getPathBetweenRows(index0, index1);
        if (paths != null && paths.length > 0) getSelectionModel().addSelectionPaths(paths);
    }
    public void removeSelectionInterval(int index0, int index1) {
        TreePath[] paths = getPathBetweenRows(index0, index1);
        if (paths != null && paths.length > 0) getSelectionModel().removeSelectionPaths(paths);
    }
    public void removeSelectionPath(TreePath path) { getSelectionModel().removeSelectionPath(path); }
    public void removeSelectionPaths(TreePath[] paths) { getSelectionModel().removeSelectionPaths(paths); }
    public void removeSelectionRow(int row) { removeSelectionRows(new int[] { row }); }
    public void removeSelectionRows(int[] rows) {
        if (rows != null) {
            int numRows = rows.length;
            TreePath[] paths = new TreePath[numRows];
            for (int counter = 0; counter < numRows; counter++) paths[counter] = getPathForRow(rows[counter]);
            removeSelectionPaths(paths);
        }
    }
    public void clearSelection() { getSelectionModel().clearSelection(); }
    public boolean isSelectionEmpty() { return getSelectionModel().isSelectionEmpty(); }
    // ---- ecouteurs d'expansion et de selection ----
    public void addTreeExpansionListener(TreeExpansionListener tel) { listenerList.add(TreeExpansionListener.class, tel); }
    public void removeTreeExpansionListener(TreeExpansionListener tel) { listenerList.remove(TreeExpansionListener.class, tel); }
    public TreeExpansionListener[] getTreeExpansionListeners() { return listenerList.getListeners(TreeExpansionListener.class); }
    public void addTreeWillExpandListener(TreeWillExpandListener tel) { listenerList.add(TreeWillExpandListener.class, tel); }
    public void removeTreeWillExpandListener(TreeWillExpandListener tel) { listenerList.remove(TreeWillExpandListener.class, tel); }
    public TreeWillExpandListener[] getTreeWillExpandListeners() { return listenerList.getListeners(TreeWillExpandListener.class); }
    public void fireTreeExpanded(TreePath path) {
        Object[] listeners = listenerList.getListenerList();
        TreeExpansionEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeExpansionListener.class) {
                if (e == null) e = new TreeExpansionEvent(this, path);
                ((TreeExpansionListener) listeners[i + 1]).treeExpanded(e);
            }
        }
    }
    public void fireTreeCollapsed(TreePath path) {
        Object[] listeners = listenerList.getListenerList();
        TreeExpansionEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeExpansionListener.class) {
                if (e == null) e = new TreeExpansionEvent(this, path);
                ((TreeExpansionListener) listeners[i + 1]).treeCollapsed(e);
            }
        }
    }
    public void fireTreeWillExpand(TreePath path) throws ExpandVetoException {
        Object[] listeners = listenerList.getListenerList();
        TreeExpansionEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeWillExpandListener.class) {
                if (e == null) e = new TreeExpansionEvent(this, path);
                ((TreeWillExpandListener) listeners[i + 1]).treeWillExpand(e);
            }
        }
    }
    public void fireTreeWillCollapse(TreePath path) throws ExpandVetoException {
        Object[] listeners = listenerList.getListenerList();
        TreeExpansionEvent e = null;
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeWillExpandListener.class) {
                if (e == null) e = new TreeExpansionEvent(this, path);
                ((TreeWillExpandListener) listeners[i + 1]).treeWillCollapse(e);
            }
        }
    }
    public void addTreeSelectionListener(TreeSelectionListener tsl) {
        listenerList.add(TreeSelectionListener.class, tsl);
        if (listenerList.getListenerCount(TreeSelectionListener.class) != 0 && selectionRedirector == null) {
            selectionRedirector = new TreeSelectionRedirector();
            selectionModel.addTreeSelectionListener(selectionRedirector);
        }
    }
    public void removeTreeSelectionListener(TreeSelectionListener tsl) {
        listenerList.remove(TreeSelectionListener.class, tsl);
        if (listenerList.getListenerCount(TreeSelectionListener.class) == 0 && selectionRedirector != null) {
            selectionModel.removeTreeSelectionListener(selectionRedirector);
            selectionRedirector = null;
        }
    }
    public TreeSelectionListener[] getTreeSelectionListeners() { return listenerList.getListeners(TreeSelectionListener.class); }
    protected void fireValueChanged(TreeSelectionEvent e) {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeSelectionListener.class) ((TreeSelectionListener) listeners[i + 1]).valueChanged(e);
        }
    }
    public void treeDidChange() { revalidate(); repaint(); }
    public void setVisibleRowCount(int newCount) {
        int oldCount = visibleRowCount;
        visibleRowCount = newCount;
        firePropertyChange(VISIBLE_ROW_COUNT_PROPERTY, oldCount, visibleRowCount);
        invalidate();
    }
    public int getVisibleRowCount() { return visibleRowCount; }
    private void expandRoot() {
        TreeModel model = getModel();
        if (model != null && model.getRoot() != null) expandPath(new TreePath(model.getRoot()));
    }
    public TreePath getNextMatch(String prefix, int startingRow, javax.swing.text.Position.Bias bias) {
        int max = getRowCount();
        if (prefix == null) throw new IllegalArgumentException();
        if (startingRow < 0 || startingRow >= max) throw new IllegalArgumentException();
        prefix = prefix.toUpperCase();
        int increment = (bias == javax.swing.text.Position.Bias.Forward) ? 1 : -1;
        int row = startingRow;
        do {
            TreePath path = getPathForRow(row);
            String text = convertValueToText(path.getLastPathComponent(), isRowSelected(row), isExpanded(row), true, row, false);
            if (text.toUpperCase().startsWith(prefix)) return path;
            row = (row + increment + max) % max;
        } while (row != startingRow);
        return null;
    }
    protected static class EmptySelectionModel extends DefaultTreeSelectionModel {
        protected static final EmptySelectionModel sharedInstance = new EmptySelectionModel();
        protected EmptySelectionModel() { }
        public static EmptySelectionModel sharedInstance() { return sharedInstance; }
        public void setSelectionPaths(TreePath[] paths) { }
        public void addSelectionPaths(TreePath[] paths) { }
        public void removeSelectionPaths(TreePath[] paths) { }
        public void setSelectionMode(int mode) { }
        public void setRowMapper(RowMapper mapper) { }
        public void addTreeSelectionListener(TreeSelectionListener listener) { }
        public void removeTreeSelectionListener(TreeSelectionListener listener) { }
        public void addPropertyChangeListener(java.beans.PropertyChangeListener listener) { }
        public void removePropertyChangeListener(java.beans.PropertyChangeListener listener) { }
    }
    protected class TreeSelectionRedirector implements java.io.Serializable, TreeSelectionListener {
        protected TreeSelectionRedirector() { }
        public void valueChanged(TreeSelectionEvent e) {
            TreeSelectionEvent newE = (TreeSelectionEvent) e.cloneWithSource(JTree.this);
            fireValueChanged(newE);
        }
    }
    // ---- Scrollable ----
    public Dimension getPreferredScrollableViewportSize() {
        int width = getPreferredSize().width;
        int visRows = getVisibleRowCount();
        int height = -1;
        if (isFixedRowHeight()) height = visRows * getRowHeight();
        else {
            if (visRows > 0) {
                int rc = getRowCount();
                if (rc >= visRows) {
                    Rectangle bounds = getRowBounds(visRows - 1);
                    if (bounds != null) height = bounds.y + bounds.height;
                } else if (rc > 0) {
                    Rectangle bounds = getRowBounds(0);
                    if (bounds != null) height = bounds.height * visRows;
                }
            }
            if (height == -1) height = 16 * visRows;
        }
        return new Dimension(width, height);
    }
    public int getScrollableUnitIncrement(Rectangle visibleRect, int orientation, int direction) {
        if (orientation == SwingConstants.VERTICAL) {
            int firstIndex = getClosestRowForLocation(0, visibleRect.y);
            if (firstIndex != -1) {
                Rectangle rowBounds = getRowBounds(firstIndex);
                if (rowBounds.y != visibleRect.y) {
                    if (direction < 0) return Math.max(0, (visibleRect.y - rowBounds.y));
                    return (rowBounds.y + rowBounds.height - visibleRect.y);
                }
                if (direction < 0) {
                    if (firstIndex != 0) { rowBounds = getRowBounds(firstIndex - 1); return rowBounds.height; }
                } else return rowBounds.height;
            }
            return 0;
        }
        return 4;
    }
    public int getScrollableBlockIncrement(Rectangle visibleRect, int orientation, int direction) {
        return (orientation == SwingConstants.VERTICAL) ? visibleRect.height : visibleRect.width;
    }
    public boolean getScrollableTracksViewportWidth() {
        Container parent = getParent();
        if (parent instanceof JViewport) return parent.getWidth() > getPreferredSize().width;
        return false;
    }
    public boolean getScrollableTracksViewportHeight() {
        Container parent = getParent();
        if (parent instanceof JViewport) return parent.getHeight() > getPreferredSize().height;
        return false;
    }
    // ---- expansion ----
    protected void setExpandedState(TreePath path, boolean state) {
        if (path != null) {
            Stack<TreePath> stack = new Stack<TreePath>();
            TreePath parentPath = path.getParentPath();
            while (parentPath != null) {
                if (isExpanded(parentPath)) parentPath = null;
                else { stack.push(parentPath); parentPath = parentPath.getParentPath(); }
            }
            for (int counter = stack.size() - 1; counter >= 0; counter--) {
                parentPath = stack.pop();
                if (!isExpanded(parentPath)) {
                    try { fireTreeWillExpand(parentPath); } catch (ExpandVetoException eve) { return; }
                    expandedState.put(parentPath, Boolean.TRUE);
                    expansionChanged();
                    fireTreeExpanded(parentPath);
                }
            }
            if (!state) {
                Boolean cValue = expandedState.get(path);
                if (cValue != null && cValue) {
                    try { fireTreeWillCollapse(path); } catch (ExpandVetoException eve) { return; }
                    expandedState.put(path, Boolean.FALSE);
                    expansionChanged();
                    fireTreeCollapsed(path);
                    if (removeDescendantSelectedPaths(path, false) && !isPathSelected(path)) addSelectionPath(path);
                }
            } else {
                Boolean cValue = expandedState.get(path);
                if (cValue == null || !cValue) {
                    try { fireTreeWillExpand(path); } catch (ExpandVetoException eve) { return; }
                    expandedState.put(path, Boolean.TRUE);
                    expansionChanged();
                    fireTreeExpanded(path);
                    if (scrollsOnExpand) ensureChildrenVisible(path);
                }
            }
        }
    }
    private void expansionChanged() {
        completeEditing();
        invalidateRows();
        selectionModel.resetRowSelection();
        revalidate();
        repaint();
    }
    private void ensureChildrenVisible(TreePath path) {
        int row = getRowForPath(path);
        if (row < 0 || !(getParent() instanceof JViewport)) return;
        int last = row + treeModel.getChildCount(path.getLastPathComponent());
        last = Math.min(last, getRowCount() - 1);
        Rectangle first = getRowBounds(row), end = getRowBounds(last);
        if (first == null || end == null) return;
        int visH = getParent().getHeight();
        int h = end.y + end.height - first.y;
        if (h > visH && visH > 0) h = visH;
        scrollRectToVisible(new Rectangle(first.x, first.y, Math.max(1, first.width), Math.max(1, h)));
    }
    protected Enumeration<TreePath> getDescendantToggledPaths(TreePath parent) {
        if (parent == null) return null;
        Vector<TreePath> descendants = new Vector<TreePath>();
        Enumeration<TreePath> nodes = expandedState.keys();
        while (nodes.hasMoreElements()) {
            TreePath path = nodes.nextElement();
            if (parent.isDescendant(path)) descendants.addElement(path);
        }
        return descendants.elements();
    }
    protected void removeDescendantToggledPaths(Enumeration<TreePath> toRemove) {
        if (toRemove != null) {
            while (toRemove.hasMoreElements()) {
                Enumeration<?> descendants = getDescendantToggledPaths(toRemove.nextElement());
                if (descendants != null) {
                    while (descendants.hasMoreElements()) expandedState.remove(descendants.nextElement());
                }
            }
        }
    }
    protected void clearToggledPaths() { expandedState.clear(); }
    protected TreeModelListener createTreeModelListener() { return new TreeModelHandler(); }
    protected boolean removeDescendantSelectedPaths(TreePath path, boolean includePath) {
        TreePath[] toRemove = getDescendantSelectedPaths(path, includePath);
        if (toRemove != null) {
            getSelectionModel().removeSelectionPaths(toRemove);
            return true;
        }
        return false;
    }
    private TreePath[] getDescendantSelectedPaths(TreePath path, boolean includePath) {
        TreeSelectionModel sm = getSelectionModel();
        TreePath[] selPaths = (sm != null) ? sm.getSelectionPaths() : null;
        if (selPaths != null) {
            boolean shouldRemove = false;
            for (int counter = selPaths.length - 1; counter >= 0; counter--) {
                if (selPaths[counter] != null && path.isDescendant(selPaths[counter]) && (!path.equals(selPaths[counter]) || includePath)) shouldRemove = true;
                else selPaths[counter] = null;
            }
            if (!shouldRemove) selPaths = null;
            return selPaths;
        }
        return null;
    }
    private TreePath pathOf(TreeModelEvent e) {
        TreePath path = e.getTreePath();
        if (path == null) {
            Object[] pp = e.getPath();
            if (pp != null && pp.length > 0) path = new TreePath(pp);
            else if (getModel() != null && getModel().getRoot() != null) path = new TreePath(getModel().getRoot());
        }
        return path;
    }
    void removeDescendantSelectedPaths(TreeModelEvent e) {
        TreePath pPath = pathOf(e);
        Object[] oldChildren = e.getChildren();
        TreeSelectionModel sm = getSelectionModel();
        if (sm != null && pPath != null && oldChildren != null && oldChildren.length > 0) {
            for (int counter = oldChildren.length - 1; counter >= 0; counter--)
                removeDescendantSelectedPaths(pPath.pathByAddingChild(oldChildren[counter]), true);
        }
    }
    protected class TreeModelHandler implements TreeModelListener {
        protected TreeModelHandler() { }
        public void treeNodesChanged(TreeModelEvent e) {
            if (editingComponent != null) completeEditing();
            sizesValid = false;
            revalidate();
            repaint();
        }
        public void treeNodesInserted(TreeModelEvent e) { structureTouched(); }
        public void treeStructureChanged(TreeModelEvent e) {
            if (e == null) return;
            TreePath parent = pathOf(e);
            if (parent == null) return;
            if (parent.getPathCount() == 1) {
                clearToggledPaths();
                Object treeRoot = treeModel.getRoot();
                if (treeRoot != null && !treeModel.isLeaf(treeRoot)) expandedState.put(parent, Boolean.TRUE);
            } else if (expandedState.get(parent) != null) {
                Vector<TreePath> toRemove = new Vector<TreePath>(1);
                boolean isExpanded = isExpanded(parent);
                toRemove.addElement(parent);
                removeDescendantToggledPaths(toRemove.elements());
                if (isExpanded) {
                    TreeModel model = getModel();
                    if (model == null || model.isLeaf(parent.getLastPathComponent())) collapsePath(parent);
                    else expandedState.put(parent, Boolean.TRUE);
                }
            }
            removeDescendantSelectedPaths(parent, false);
            structureTouched();
        }
        public void treeNodesRemoved(TreeModelEvent e) {
            if (e == null) return;
            TreePath parent = pathOf(e);
            Object[] children = e.getChildren();
            if (children == null) return;
            Vector<TreePath> toRemove = new Vector<TreePath>(Math.max(1, children.length));
            for (int counter = children.length - 1; counter >= 0; counter--) {
                TreePath rPath = parent.pathByAddingChild(children[counter]);
                if (expandedState.get(rPath) != null) toRemove.addElement(rPath);
            }
            if (toRemove.size() > 0) removeDescendantToggledPaths(toRemove.elements());
            TreeModel model = getModel();
            if (model == null || model.isLeaf(parent.getLastPathComponent())) expandedState.remove(parent);
            removeDescendantSelectedPaths(e);
            structureTouched();
        }
    }
    private void structureTouched() {
        completeEditing();
        invalidateRows();
        selectionModel.resetRowSelection();
        revalidate();
        repaint();
    }
    public static class DynamicUtilTreeNode extends DefaultMutableTreeNode {
        protected boolean hasChildren;
        protected Object childValue;
        protected boolean loadedChildren;
        public static void createChildren(DefaultMutableTreeNode parent, Object children) {
            if (children instanceof Vector) {
                Vector<?> childVector = (Vector) children;
                for (int counter = 0, maxCounter = childVector.size(); counter < maxCounter; counter++)
                    parent.add(new DynamicUtilTreeNode(childVector.elementAt(counter), childVector.elementAt(counter)));
            } else if (children instanceof Hashtable) {
                Hashtable<?, ?> childHT = (Hashtable) children;
                Enumeration<?> keys = childHT.keys();
                while (keys.hasMoreElements()) {
                    Object aKey = keys.nextElement();
                    parent.add(new DynamicUtilTreeNode(aKey, childHT.get(aKey)));
                }
            } else if (children instanceof Object[]) {
                Object[] childArray = (Object[]) children;
                for (int counter = 0, maxCounter = childArray.length; counter < maxCounter; counter++)
                    parent.add(new DynamicUtilTreeNode(childArray[counter], childArray[counter]));
            }
        }
        public DynamicUtilTreeNode(Object value, Object children) {
            super(value);
            loadedChildren = false;
            childValue = children;
            if (children != null) {
                if (children instanceof Vector) setAllowsChildren(true);
                else if (children instanceof Hashtable) setAllowsChildren(true);
                else if (children instanceof Object[]) setAllowsChildren(true);
                else setAllowsChildren(false);
            } else setAllowsChildren(false);
        }
        public boolean isLeaf() { return !getAllowsChildren(); }
        public int getChildCount() {
            if (!loadedChildren) loadChildren();
            return super.getChildCount();
        }
        protected void loadChildren() {
            loadedChildren = true;
            createChildren(this, childValue);
        }
        public TreeNode getChildAt(int index) {
            if (!loadedChildren) loadChildren();
            return super.getChildAt(index);
        }
        public Enumeration<TreeNode> children() {
            if (!loadedChildren) loadChildren();
            return super.children();
        }
    }
    // ---- lignes visibles ----
    void invalidateRows() { rowsValid = false; sizesValid = false; }
    private void ensureRows() {
        if (rowsValid) return;
        rowList = new ArrayList<TreePath>();
        rowIndex = new HashMap<TreePath, Integer>();
        if (treeModel != null && treeModel.getRoot() != null) {
            Object root = treeModel.getRoot();
            TreePath rp = new TreePath(root);
            if (rootVisible) {
                rowIndex.put(rp, rowList.size());
                rowList.add(rp);
                if (!treeModel.isLeaf(root) && Boolean.TRUE.equals(expandedState.get(rp))) addChildRows(rp);
            } else if (!treeModel.isLeaf(root) && Boolean.TRUE.equals(expandedState.get(rp))) addChildRows(rp);
        }
        rowsValid = true;
    }
    private void addChildRows(TreePath parent) {
        Object node = parent.getLastPathComponent();
        int n = treeModel.getChildCount(node);
        for (int i = 0; i < n; i++) {
            Object child = treeModel.getChild(node, i);
            TreePath cp = parent.pathByAddingChild(child);
            rowIndex.put(cp, rowList.size());
            rowList.add(cp);
            if (!treeModel.isLeaf(child) && Boolean.TRUE.equals(expandedState.get(cp))) addChildRows(cp);
        }
    }
    private int rowX(TreePath path) {
        int depth = path.getPathCount() - 1;
        int offset = rootVisible ? (showsRootHandles ? 1 : 0) : (showsRootHandles ? 0 : -1);
        return (LEFT_INDENT + RIGHT_INDENT) * (depth + offset);
    }
    private Component rendererFor(int row, TreePath path) {
        TreeCellRenderer r = cellRenderer != null ? cellRenderer : defaultRenderer;
        Object v = path.getLastPathComponent();
        boolean sel = isPathSelected(path);
        boolean exp = isExpanded(path);
        boolean leaf = treeModel.isLeaf(v);
        boolean focus = isFocusOwner() && row == getLeadSelectionRow();
        Component c = r.getTreeCellRendererComponent(this, v, sel, exp, leaf, row, focus);
        JComponent.attach(c, this);
        return c;
    }
    private void ensureSizes() {
        ensureRows();
        if (sizesValid) return;
        int n = rowList.size();
        rowYs = new int[n + 1];
        rowWs = new int[n];
        rowHs = new int[n];
        maxExtent = 0;
        for (int i = 0; i < n; i++) {
            TreePath p = rowList.get(i);
            Dimension d = rendererFor(i, p).getPreferredSize();
            rowWs[i] = d.width;
            rowHs[i] = rowHeight > 0 ? rowHeight : d.height;
            rowYs[i + 1] = rowYs[i] + rowHs[i];
            maxExtent = Math.max(maxExtent, rowX(p) + d.width);
        }
        sizesValid = true;
    }
    private int rowAtY(int y) {
        int n = rowList.size();
        int lo = 0, hi = n - 1;
        while (lo < hi) {
            int mid = (lo + hi + 1) >>> 1;
            if (rowYs[mid] <= y) lo = mid; else hi = mid - 1;
        }
        return lo;
    }
    public void setFont(Font f) { super.setFont(f); sizesValid = false; }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        ensureSizes();
        Insets in = getInsets();
        return new Dimension(maxExtent + in.left + in.right, rowYs[rowList.size()] + in.top + in.bottom);
    }
    public Dimension getMinimumSize() { return minSize != null ? new Dimension(minSize) : new Dimension(0, 0); }
    // ---- edition ----
    private final CellEditorListener editorListener = new CellEditorListener() {
        public void editingStopped(ChangeEvent e) { finishEditing(true); }
        public void editingCanceled(ChangeEvent e) { finishEditing(false); }
    };
    private void finishEditing(boolean commit) {
        if (editingComponent == null) return;
        TreePath path = editingPath;
        Object newValue = commit && cellEditor != null ? cellEditor.getCellEditorValue() : null;
        boolean hadFocus = false;
        hadFocus = hasFocusWithin(editingComponent);
        Component ec = editingComponent;
        if (editorKeys != null) removeKeyFromAll(ec, editorKeys);
        editingComponent = null;
        editingPath = null;
        remove(ec);
        if (commit && path != null) treeModel.valueForPathChanged(path, newValue);
        if (hadFocus) requestFocus();
        invalidateRows();
        revalidate();
        repaint();
    }
    private boolean hasFocusWithin(Component c) {
        if (c.isFocusOwner()) return true;
        if (c instanceof Container) for (Component k : ((Container) c).getComponents()) if (hasFocusWithin(k)) return true;
        return false;
    }
    private void removeKeyFromAll(Component c, KeyListener l) {
        c.removeKeyListener(l);
        if (c instanceof Container) for (Component k : ((Container) c).getComponents()) removeKeyFromAll(k, l);
    }
    private void addKeyToAll(Component c, KeyListener l) {
        c.addKeyListener(l);
        if (c instanceof Container) for (Component k : ((Container) c).getComponents()) addKeyToAll(k, l);
    }
    private boolean completeEditing() {
        if (editingComponent != null && cellEditor != null) {
            if (invokesStopCellEditing) return cellEditor.stopCellEditing();
            cellEditor.cancelCellEditing();
        }
        return true;
    }
    private boolean startEditing(TreePath path, EventObject event) {
        completeEditing();
        if (cellEditor != null && isPathEditable(path)) {
            int row = getRowForPath(path);
            if (row < 0) return false;
            if (cellEditor.isCellEditable(event)) {
                Object v = path.getLastPathComponent();
                Component comp = cellEditor.getTreeCellEditorComponent(this, v, isPathSelected(path), isExpanded(path), treeModel.isLeaf(v), row);
                Rectangle nodeBounds = getPathBounds(path);
                Dimension es = comp.getPreferredSize();
                if (rowHeight > 0) es.height = rowHeight;
                comp.setBounds(nodeBounds.x, nodeBounds.y, Math.max(es.width, nodeBounds.width + 20), Math.max(es.height, nodeBounds.height));
                editingComponent = comp;
                editingPath = path;
                add(comp);
                if (comp instanceof Container) ((Container) comp).validate();
                editorKeys = new KeyAdapter() {
                    public void keyPressed(KeyEvent e) {
                        if (e.getKeyCode() == KeyEvent.VK_ESCAPE) { cancelEditing(); e.consume(); }
                    }
                };
                addKeyToAll(comp, editorKeys);
                focusFirstField(comp);
                repaint();
                return true;
            }
        }
        return false;
    }
    private boolean focusFirstField(Component c) {
        if (c instanceof javax.swing.text.JTextComponent) { c.requestFocus(); return true; }
        if (c instanceof Container) for (Component k : ((Container) c).getComponents()) if (focusFirstField(k)) return true;
        return false;
    }
    // ---- souris et clavier ----
    public boolean wantsMouse() { return true; }
    public boolean wantsKeys() { return true; }
    public boolean focusTraversable() { return true; }
    private boolean shouldPaintExpandControl(TreePath path) {
        if (treeModel.isLeaf(path.getLastPathComponent())) return false;
        int depth = path.getPathCount() - 1;
        if ((depth == 0 || (depth == 1 && !rootVisible)) && !showsRootHandles) return false;
        return true;
    }
    private boolean inExpandControl(TreePath path, int mx) {
        if (!shouldPaintExpandControl(path)) return false;
        int cx = getInsets().left + rowX(path) - RIGHT_INDENT;
        return mx >= cx - 6 && mx < cx + 6;
    }
    private void toggle(TreePath path) {
        if (isExpanded(path)) collapsePath(path); else expandPath(path);
    }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (!enabled || e.getID() != MouseEvent.MOUSE_PRESSED || e.getButton() != 1) return;
        int x = e.getX(), y = e.getY();
        TreePath path = getClosestPathForLocation(x, y);
        if (path == null) { if (editingComponent != null) completeEditing(); return; }
        Rectangle b = getPathBounds(path);
        if (y >= b.y + b.height) { if (editingComponent != null) completeEditing(); return; }
        if (editTimer != null) editTimer.stop();
        if (editingComponent != null) completeEditing();
        if (inExpandControl(path, x)) {
            toggle(path);
            return;
        }
        if (x > b.x && x <= b.x + b.width) {
            boolean alreadySelected = isPathSelected(path) && getSelectionCount() == 1;
            if (e.isControlDown()) {
                if (isPathSelected(path)) removeSelectionPath(path); else addSelectionPath(path);
            } else if (e.isShiftDown() && getAnchorSelectionPath() != null && getRowForPath(getAnchorSelectionPath()) >= 0) {
                setSelectionInterval(getRowForPath(getAnchorSelectionPath()), getRowForPath(path));
            } else {
                setSelectionPath(path);
            }
            if (toggleClickCount > 0 && e.getClickCount() > 0 && e.getClickCount() % toggleClickCount == 0) toggle(path);
            else if (alreadySelected && editable && cellEditor != null && e.getClickCount() == 1 && isPathEditable(path)) {
                final TreePath ep = path;
                editTimerPath = path;
                if (editTimer == null) {
                    editTimer = new javax.swing.Timer(1200, new ActionListener() {
                        public void actionPerformed(ActionEvent ev) {
                            if (editTimerPath != null && editTimerPath.equals(getSelectionPath())) startEditingAtPath(editTimerPath);
                        }
                    });
                    editTimer.setRepeats(false);
                }
                editTimer.restart();
            }
        }
    }
    private void moveTo(int row) {
        if (row < 0 || row >= getRowCount()) return;
        setSelectionRow(row);
        scrollRowToVisible(row);
    }
    protected void processKeyEvent(KeyEvent e) {
        super.processKeyEvent(e);
        if (e.isConsumed() || !enabled) return;
        int id = e.getID();
        int rows = getRowCount();
        if (id == KeyEvent.KEY_TYPED) {
            char ch = e.getKeyChar();
            if (ch >= 32 && ch != 127 && rows > 0) {
                long now = System.currentTimeMillis();
                if (now - typedAt > 1000) typed = "";
                typedAt = now;
                typed += ch;
                int start = Math.max(0, getLeadSelectionRow());
                if (typed.length() == 1) start = (start + 1) % rows;
                TreePath p = getNextMatch(typed, start, javax.swing.text.Position.Bias.Forward);
                if (p != null) { setSelectionPath(p); scrollPathToVisible(p); }
                e.consume();
            }
            return;
        }
        if (id != KeyEvent.KEY_PRESSED || rows == 0) return;
        int lead = getLeadSelectionRow();
        TreePath leadP = getLeadSelectionPath();
        int page = Math.max(1, getVisibleRect().height / Math.max(1, rowHeight > 0 ? rowHeight : 18) - 1);
        switch (e.getKeyCode()) {
            case KeyEvent.VK_DOWN: moveTo(lead < 0 ? 0 : Math.min(rows - 1, lead + 1)); break;
            case KeyEvent.VK_UP: moveTo(lead < 0 ? 0 : Math.max(0, lead - 1)); break;
            case KeyEvent.VK_PAGE_DOWN: moveTo(Math.min(rows - 1, Math.max(0, lead) + page)); break;
            case KeyEvent.VK_PAGE_UP: moveTo(Math.max(0, Math.max(0, lead) - page)); break;
            case KeyEvent.VK_HOME: moveTo(0); break;
            case KeyEvent.VK_END: moveTo(rows - 1); break;
            case KeyEvent.VK_RIGHT:
                if (leadP != null) {
                    Object v = leadP.getLastPathComponent();
                    if (!treeModel.isLeaf(v)) {
                        if (!isExpanded(leadP)) expandPath(leadP);
                        else if (treeModel.getChildCount(v) > 0) moveTo(lead + 1);
                    }
                }
                break;
            case KeyEvent.VK_LEFT:
                if (leadP != null) {
                    if (isExpanded(leadP) && !treeModel.isLeaf(leadP.getLastPathComponent())) collapsePath(leadP);
                    else {
                        TreePath pp = leadP.getParentPath();
                        if (pp != null) {
                            int r = getRowForPath(pp);
                            if (r >= 0) moveTo(r);
                        }
                    }
                }
                break;
            case KeyEvent.VK_ENTER:
                if (leadP != null && !treeModel.isLeaf(leadP.getLastPathComponent())) toggle(leadP);
                break;
            case KeyEvent.VK_SPACE:
                if (leadP != null) { if (isPathSelected(leadP)) removeSelectionPath(leadP); else addSelectionPath(leadP); }
                break;
            case KeyEvent.VK_F2:
                if (leadP != null && isPathEditable(leadP)) startEditingAtPath(leadP);
                break;
            case KeyEvent.VK_A:
                if (e.isControlDown() && selectionModel.getSelectionMode() == TreeSelectionModel.DISCONTIGUOUS_TREE_SELECTION) { setSelectionInterval(0, rows - 1); break; }
                return;
            default: return;
        }
        e.consume();
    }
    // ---- peinture ----
    private void dotH(Graphics g, int x1, int x2, int y) { for (int x = x1; x <= x2; x += 2) g.fillRect(x, y, 1, 1); }
    private void dotV(Graphics g, int x, int y1, int y2) { for (int y = y1; y <= y2; y += 2) g.fillRect(x, y, 1, 1); }
    private void paintConnectors(Graphics g, TreePath path, int X, int y, int h) {
        int mid = y + h / 2;
        int px = X - RIGHT_INDENT;
        TreePath parentPath = path.getParentPath();
        Object node = path.getLastPathComponent();
        g.setColor(new Color(120, 132, 145));
        if (parentPath != null && px >= 0) {
            Object parent = parentPath.getLastPathComponent();
            boolean parentRow = rootVisible || parentPath.getPathCount() > 1;
            int idx = treeModel.getIndexOfChild(parent, node);
            int count = treeModel.getChildCount(parent);
            boolean last = idx == count - 1;
            boolean up = parentRow || idx > 0;
            if (up || !last) dotV(g, px, up ? y : mid, last ? mid : y + h - 1);
            dotH(g, px, X - 3, mid);
        }
        // lignes de continuation des ancetres
        TreePath a = parentPath;
        while (a != null && a.getParentPath() != null) {
            TreePath ap = a.getParentPath();
            int ax = getInsets().left + rowX(a) - RIGHT_INDENT;
            if (ax - getInsets().left >= 0) {
                int idx = treeModel.getIndexOfChild(ap.getLastPathComponent(), a.getLastPathComponent());
                if (idx >= 0 && idx < treeModel.getChildCount(ap.getLastPathComponent()) - 1) dotV(g, ax, y, y + h - 1);
            }
            a = ap;
        }
        // trait descendant d'un noeud deplie
        if (isExpanded(path) && !treeModel.isLeaf(node) && treeModel.getChildCount(node) > 0 && (rootVisible || path.getPathCount() > 1)) {
            dotV(g, X + LEFT_INDENT, mid + 8, y + h - 1);
        }
    }
    protected void paintComponent(Graphics g) {
        g.setColor(getBackground());
        g.fillRect(0, 0, width, height);
        ensureSizes();
        int n = rowList.size();
        if (n == 0) return;
        Rectangle clip = g.getClipBounds();
        if (clip == null) clip = new Rectangle(0, 0, width, height);
        Insets in = getInsets();
        int y0 = clip.y - in.top, y1 = clip.y + clip.height - in.top;
        int first = y0 <= 0 ? 0 : (y0 >= rowYs[n] ? n - 1 : rowAtY(y0));
        for (int i = first; i < n; i++) {
            int y = rowYs[i];
            if (y >= y1) break;
            TreePath p = rowList.get(i);
            int X = in.left + rowX(p);
            int h = rowHs[i];
            paintConnectors(g, p, X, in.top + y, h);
            if (shouldPaintExpandControl(p)) {
                Icon ic = isExpanded(p) ? TreeIcons.EXPANDED : TreeIcons.COLLAPSED;
                ic.paintIcon(this, g, X - RIGHT_INDENT - 4, in.top + y + (h - 9) / 2);
            }
            if (editingComponent != null && p.equals(editingPath)) continue;
            Component c = rendererFor(i, p);
            JComponent.paintCell(g, c, this, X, in.top + y, rowWs[i], h);
        }
    }
}
