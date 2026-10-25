package javax.swing;
import java.util.*;
import javax.swing.event.*;
public abstract class RowSorter<M> {
    private final ArrayList<RowSorterListener> listeners = new ArrayList<>();
    public RowSorter() { }
    public abstract M getModel();
    public abstract void toggleSortOrder(int column);
    public abstract int convertRowIndexToModel(int index);
    public abstract int convertRowIndexToView(int index);
    public abstract void setSortKeys(List<? extends SortKey> keys);
    public abstract List<? extends SortKey> getSortKeys();
    public abstract int getViewRowCount();
    public abstract int getModelRowCount();
    public abstract void modelStructureChanged();
    public abstract void allRowsChanged();
    public abstract void rowsInserted(int firstRow, int endRow);
    public abstract void rowsDeleted(int firstRow, int endRow);
    public abstract void rowsUpdated(int firstRow, int endRow);
    public abstract void rowsUpdated(int firstRow, int endRow, int column);
    public void addRowSorterListener(RowSorterListener l) { listeners.add(l); }
    public void removeRowSorterListener(RowSorterListener l) { listeners.remove(l); }
    protected void fireSortOrderChanged() { fire(new RowSorterEvent(this)); }
    protected void fireRowSorterChanged(int[] lastRowIndexToModel) { fire(new RowSorterEvent(this, RowSorterEvent.Type.SORTED, lastRowIndexToModel)); }
    void fire(RowSorterEvent e) { for (RowSorterListener l : new ArrayList<>(listeners)) l.sorterChanged(e); }
    public static class SortKey {
        private int column;
        private SortOrder sortOrder;
        public SortKey(int column, SortOrder sortOrder) {
            if (sortOrder == null) throw new IllegalArgumentException("sort order must be non-null");
            this.column = column;
            this.sortOrder = sortOrder;
        }
        public final int getColumn() { return column; }
        public final SortOrder getSortOrder() { return sortOrder; }
        public int hashCode() { int result = 17; result = 37 * result + column; result = 37 * result + sortOrder.hashCode(); return result; }
        public boolean equals(Object o) {
            if (o == this) return true;
            if (o instanceof SortKey) return ((SortKey) o).column == column && ((SortKey) o).sortOrder == sortOrder;
            return false;
        }
    }
}
