package javax.swing.tree;
import java.beans.PropertyChangeListener;
import java.beans.PropertyChangeSupport;
import java.io.Serializable;
import java.util.*;
import javax.swing.DefaultListSelectionModel;
import javax.swing.event.*;
public class DefaultTreeSelectionModel implements Cloneable, Serializable, TreeSelectionModel {
    public static final String SELECTION_MODE_PROPERTY = "selectionMode";
    protected PropertyChangeSupport changeSupport;
    protected TreePath[] selection;
    protected EventListenerList listenerList = new EventListenerList();
    protected transient RowMapper rowMapper;
    protected DefaultListSelectionModel listSelectionModel;
    protected int selectionMode;
    protected TreePath leadPath;
    protected int leadIndex;
    protected int leadRow;
    public DefaultTreeSelectionModel() {
        listSelectionModel = new DefaultListSelectionModel();
        selectionMode = DISCONTIGUOUS_TREE_SELECTION;
        leadIndex = leadRow = -1;
    }
    public void setRowMapper(RowMapper newMapper) { rowMapper = newMapper; resetRowSelection(); }
    public RowMapper getRowMapper() { return rowMapper; }
    private static int validateSelectionMode(int mode) {
        return (mode != SINGLE_TREE_SELECTION && mode != CONTIGUOUS_TREE_SELECTION && mode != DISCONTIGUOUS_TREE_SELECTION) ? DISCONTIGUOUS_TREE_SELECTION : mode;
    }
    public void setSelectionMode(int mode) {
        int oldMode = selectionMode;
        selectionMode = validateSelectionMode(mode);
        if (oldMode != selectionMode && changeSupport != null)
            changeSupport.firePropertyChange(SELECTION_MODE_PROPERTY, Integer.valueOf(oldMode), Integer.valueOf(selectionMode));
    }
    public int getSelectionMode() { return selectionMode; }
    private ArrayList<TreePath> current() {
        ArrayList<TreePath> l = new ArrayList<>();
        if (selection != null) for (TreePath p : selection) l.add(p);
        return l;
    }
    private void store(ArrayList<TreePath> l) { selection = l.toArray(new TreePath[0]); }
    public void setSelectionPath(TreePath path) {
        if (path == null) setSelectionPaths(null);
        else setSelectionPaths(new TreePath[] { path });
    }
    public void setSelectionPaths(TreePath[] pPaths) {
        TreePath[] paths = pPaths;
        int newCount = paths == null ? 0 : paths.length;
        int oldCount = selection == null ? 0 : selection.length;
        if (newCount + oldCount == 0) return;
        if (selectionMode == SINGLE_TREE_SELECTION) {
            if (newCount > 1) { paths = new TreePath[] { pPaths[0] }; newCount = 1; }
        } else if (selectionMode == CONTIGUOUS_TREE_SELECTION) {
            if (newCount > 0 && !arePathsContiguous(paths)) { paths = new TreePath[] { pPaths[0] }; newCount = 1; }
        }
        TreePath beginLead = leadPath;
        ArrayList<TreePath> oldSel = current();
        ArrayList<TreePath> newSel = new ArrayList<>();
        ArrayList<Object[]> changed = new ArrayList<>();
        leadPath = null;
        for (int i = 0; i < newCount; i++) {
            TreePath p = paths[i];
            if (p != null && !newSel.contains(p)) {
                newSel.add(p);
                if (!oldSel.contains(p)) changed.add(new Object[] { p, Boolean.TRUE });
                leadPath = p;
            }
        }
        for (TreePath p : oldSel) if (!newSel.contains(p)) changed.add(new Object[] { p, Boolean.FALSE });
        store(newSel);
        updateLeadIndex();
        resetRowSelection();
        if (changed.size() > 0) notifyChange(changed, beginLead);
    }
    public void addSelectionPath(TreePath path) {
        if (path != null) addSelectionPaths(new TreePath[] { path });
    }
    public void addSelectionPaths(TreePath[] paths) {
        int n = paths == null ? 0 : paths.length;
        if (n == 0) return;
        if (selectionMode == SINGLE_TREE_SELECTION) { setSelectionPaths(paths); return; }
        if (selectionMode == CONTIGUOUS_TREE_SELECTION && !canPathsBeAdded(paths)) {
            if (arePathsContiguous(paths)) setSelectionPaths(paths);
            else setSelectionPaths(new TreePath[] { paths[0] });
            return;
        }
        TreePath beginLead = leadPath;
        ArrayList<TreePath> sel = current();
        ArrayList<Object[]> changed = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            TreePath p = paths[i];
            if (p != null) {
                if (!sel.contains(p)) { sel.add(p); changed.add(new Object[] { p, Boolean.TRUE }); }
                leadPath = p;
            }
        }
        if (leadPath == null) leadPath = beginLead;
        if (changed.size() > 0) {
            store(sel);
            updateLeadIndex();
            resetRowSelection();
            notifyChange(changed, beginLead);
        } else leadPath = beginLead;
    }
    public void removeSelectionPath(TreePath path) {
        if (path != null) removeSelectionPaths(new TreePath[] { path });
    }
    public void removeSelectionPaths(TreePath[] paths) {
        if (paths == null || selection == null || paths.length == 0) return;
        if (!canPathsBeRemoved(paths)) { clearSelection(); return; }
        ArrayList<TreePath> sel = current();
        ArrayList<Object[]> changed = new ArrayList<>();
        for (int i = paths.length - 1; i >= 0; i--) {
            TreePath p = paths[i];
            if (p != null && sel.contains(p)) { sel.remove(p); changed.add(new Object[] { p, Boolean.FALSE }); }
        }
        if (changed.size() > 0) {
            TreePath beginLead = leadPath;
            if (sel.isEmpty()) { selection = null; leadPath = null; }
            else { store(sel); leadPath = sel.get(sel.size() - 1); }
            updateLeadIndex();
            resetRowSelection();
            notifyChange(changed, beginLead);
        }
    }
    public TreePath getSelectionPath() { return (selection != null && selection.length > 0) ? selection[0] : null; }
    public TreePath[] getSelectionPaths() {
        if (selection != null) return selection.clone();
        return new TreePath[0];
    }
    public int getSelectionCount() { return selection == null ? 0 : selection.length; }
    public boolean isPathSelected(TreePath path) {
        if (path == null || selection == null) return false;
        for (TreePath p : selection) if (p.equals(path)) return true;
        return false;
    }
    public boolean isSelectionEmpty() { return selection == null || selection.length == 0; }
    public void clearSelection() {
        if (selection != null && selection.length > 0) {
            int selSize = selection.length;
            boolean[] newness = new boolean[selSize];
            TreeSelectionEvent event = new TreeSelectionEvent(this, selection, newness, leadPath, null);
            leadPath = null;
            leadIndex = leadRow = -1;
            selection = null;
            resetRowSelection();
            fireValueChanged(event);
        }
    }
    public void addTreeSelectionListener(TreeSelectionListener x) { listenerList.add(TreeSelectionListener.class, x); }
    public void removeTreeSelectionListener(TreeSelectionListener x) { listenerList.remove(TreeSelectionListener.class, x); }
    public TreeSelectionListener[] getTreeSelectionListeners() { return listenerList.getListeners(TreeSelectionListener.class); }
    protected void fireValueChanged(TreeSelectionEvent e) {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == TreeSelectionListener.class) ((TreeSelectionListener) listeners[i + 1]).valueChanged(e);
        }
    }
    public <T extends EventListener> T[] getListeners(Class<T> listenerType) { return listenerList.getListeners(listenerType); }
    public int[] getSelectionRows() {
        if (rowMapper != null && selection != null && selection.length > 0) {
            int[] rows = rowMapper.getRowsForPaths(selection);
            if (rows != null) {
                int invisCount = 0;
                for (int counter = rows.length - 1; counter >= 0; counter--) if (rows[counter] == -1) invisCount++;
                if (invisCount > 0) {
                    if (invisCount == rows.length) rows = null;
                    else {
                        int[] tempRows = new int[rows.length - invisCount];
                        for (int counter = rows.length - 1, visCounter = 0; counter >= 0; counter--) {
                            if (rows[counter] != -1) tempRows[visCounter++] = rows[counter];
                        }
                        rows = tempRows;
                    }
                }
            }
            return rows;
        }
        return new int[0];
    }
    public int getMinSelectionRow() { return listSelectionModel.getMinSelectionIndex(); }
    public int getMaxSelectionRow() { return listSelectionModel.getMaxSelectionIndex(); }
    public boolean isRowSelected(int row) { return listSelectionModel.isSelectedIndex(row); }
    public void resetRowSelection() {
        listSelectionModel.clearSelection();
        if (selection != null && rowMapper != null) {
            int[] rows = rowMapper.getRowsForPaths(selection);
            for (int counter = 0, maxCounter = selection.length; counter < maxCounter; counter++) {
                int aRow = rows[counter];
                if (aRow != -1) listSelectionModel.addSelectionInterval(aRow, aRow);
            }
            if (leadIndex != -1 && rows != null) leadRow = rows[leadIndex];
            else if (leadPath != null) {
                int[] r = rowMapper.getRowsForPaths(new TreePath[] { leadPath });
                leadRow = (r != null) ? r[0] : -1;
            } else leadRow = -1;
            insureRowContinuity();
        } else leadRow = -1;
    }
    public int getLeadSelectionRow() { return leadRow; }
    public TreePath getLeadSelectionPath() { return leadPath; }
    public synchronized void addPropertyChangeListener(PropertyChangeListener listener) {
        if (changeSupport == null) changeSupport = new PropertyChangeSupport(this);
        changeSupport.addPropertyChangeListener(listener);
    }
    public synchronized void removePropertyChangeListener(PropertyChangeListener listener) {
        if (changeSupport == null) return;
        changeSupport.removePropertyChangeListener(listener);
    }
    public PropertyChangeListener[] getPropertyChangeListeners() {
        if (changeSupport == null) return new PropertyChangeListener[0];
        return changeSupport.getPropertyChangeListeners();
    }
    protected void insureRowContinuity() {
        if (selectionMode == CONTIGUOUS_TREE_SELECTION && selection != null && rowMapper != null) {
            DefaultListSelectionModel lModel = listSelectionModel;
            int min = lModel.getMinSelectionIndex();
            if (min != -1) {
                for (int counter = min, maxCounter = lModel.getMaxSelectionIndex(); counter <= maxCounter; counter++) {
                    if (!lModel.isSelectedIndex(counter)) {
                        if (counter == min) clearSelection();
                        else {
                            TreePath[] newSel = new TreePath[counter - min];
                            int[] selectionIndex = rowMapper.getRowsForPaths(selection);
                            for (int i = 0; i < selectionIndex.length; i++) {
                                if (selectionIndex[i] < counter) newSel[selectionIndex[i] - min] = selection[i];
                            }
                            setSelectionPaths(newSel);
                            break;
                        }
                    }
                }
            }
        } else if (selectionMode == SINGLE_TREE_SELECTION && selection != null && selection.length > 1) {
            setSelectionPath(selection[0]);
        }
    }
    protected boolean arePathsContiguous(TreePath[] paths) {
        if (rowMapper == null || paths.length < 2) return true;
        BitSet bitSet = new BitSet(32);
        int pathCount = paths.length;
        int validCount = 0;
        int min = rowMapper.getRowsForPaths(new TreePath[] { paths[0] })[0];
        for (int counter = 0; counter < pathCount; counter++) {
            if (paths[counter] != null) {
                int[] rows = rowMapper.getRowsForPaths(new TreePath[] { paths[counter] });
                if (rows == null) return false;
                int anIndex = rows[0];
                if (anIndex == -1 || anIndex < (min - pathCount) || anIndex > (min + pathCount)) return false;
                if (anIndex < min) min = anIndex;
                if (!bitSet.get(anIndex)) { bitSet.set(anIndex); validCount++; }
            }
        }
        int maxCounter = validCount + min;
        for (int counter = min; counter < maxCounter; counter++) if (!bitSet.get(counter)) return false;
        return true;
    }
    protected boolean canPathsBeAdded(TreePath[] paths) {
        if (paths == null || paths.length == 0 || rowMapper == null || selection == null || selectionMode == DISCONTIGUOUS_TREE_SELECTION) return true;
        BitSet bitSet = new BitSet();
        DefaultListSelectionModel lModel = listSelectionModel;
        int min = lModel.getMinSelectionIndex();
        int max = lModel.getMaxSelectionIndex();
        if (min != -1) {
            for (int counter = min; counter <= max; counter++) if (lModel.isSelectedIndex(counter)) bitSet.set(counter);
        } else {
            min = max = rowMapper.getRowsForPaths(new TreePath[] { paths[0] })[0];
        }
        for (int counter = paths.length - 1; counter >= 0; counter--) {
            if (paths[counter] != null) {
                int[] rows = rowMapper.getRowsForPaths(new TreePath[] { paths[counter] });
                if (rows == null) return false;
                int anIndex = rows[0];
                min = Math.min(anIndex, min);
                max = Math.max(anIndex, max);
                if (anIndex == -1) return false;
                bitSet.set(anIndex);
            }
        }
        for (int counter = min; counter <= max; counter++) if (!bitSet.get(counter)) return false;
        return true;
    }
    protected boolean canPathsBeRemoved(TreePath[] paths) {
        if (rowMapper == null || selection == null || selectionMode == DISCONTIGUOUS_TREE_SELECTION) return true;
        BitSet bitSet = new BitSet();
        int min = -1;
        int validCount = 0;
        for (int counter = selection.length - 1; counter >= 0; counter--) {
            boolean removed = false;
            for (TreePath p : paths) if (p != null && p.equals(selection[counter])) removed = true;
            if (!removed) {
                int[] rows = rowMapper.getRowsForPaths(new TreePath[] { selection[counter] });
                if (rows != null && rows[0] != -1 && !bitSet.get(rows[0])) {
                    validCount++;
                    if (min == -1) min = rows[0]; else min = Math.min(min, rows[0]);
                    bitSet.set(rows[0]);
                }
            }
        }
        if (validCount > 1) {
            for (int counter = min + validCount - 1; counter >= min; counter--) if (!bitSet.get(counter)) return false;
        }
        return true;
    }
    private void notifyChange(ArrayList<Object[]> changed, TreePath oldLeadSelection) {
        int n = changed.size();
        boolean[] newness = new boolean[n];
        TreePath[] paths = new TreePath[n];
        for (int i = 0; i < n; i++) {
            paths[i] = (TreePath) changed.get(i)[0];
            newness[i] = ((Boolean) changed.get(i)[1]).booleanValue();
        }
        fireValueChanged(new TreeSelectionEvent(this, paths, newness, oldLeadSelection, leadPath));
    }
    protected void updateLeadIndex() {
        if (leadPath != null) {
            if (selection == null) { leadPath = null; leadIndex = leadRow = -1; }
            else {
                leadRow = leadIndex = -1;
                for (int counter = selection.length - 1; counter >= 0; counter--) {
                    if (selection[counter].equals(leadPath)) { leadIndex = counter; break; }
                }
            }
        } else leadIndex = -1;
    }
    protected void insureUniqueness() { }
    public String toString() {
        int selCount = getSelectionCount();
        StringBuilder sb = new StringBuilder();
        int[] rows = rowMapper != null ? rowMapper.getRowsForPaths(selection) : null;
        sb.append(getClass().getName() + " " + hashCode() + " [ ");
        for (int counter = 0; counter < selCount; counter++) {
            if (rows != null) sb.append(selection[counter] + "@" + rows[counter] + " ");
            else sb.append(selection[counter] + " ");
        }
        sb.append("]");
        return sb.toString();
    }
    public Object clone() throws CloneNotSupportedException {
        DefaultTreeSelectionModel clone = (DefaultTreeSelectionModel) super.clone();
        clone.changeSupport = null;
        if (selection != null) clone.selection = selection.clone();
        clone.listenerList = new EventListenerList();
        clone.listSelectionModel = (DefaultListSelectionModel) listSelectionModel.clone();
        return clone;
    }
}
