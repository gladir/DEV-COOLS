package javax.swing;
import java.text.Collator;
import java.util.*;
import javax.swing.event.*;
public abstract class DefaultRowSorter<M, I> extends RowSorter<M> {
    private ModelWrapper<M, I> modelWrapper;
    private int[] viewToModel;
    private int[] modelToView;
    private Comparator<?>[] comparators;
    private boolean[] isSortable;
    private List<SortKey> sortKeys = Collections.emptyList();
    private RowFilter<? super M, ? super I> filter;
    private int maxSortKeys = 3;
    private boolean sortsOnUpdates;
    private int modelRowCount;
    private static final Comparator<Object> COMPARABLE_COMPARATOR = new Comparator<Object>() {
        @SuppressWarnings("unchecked")
        public int compare(Object o1, Object o2) { return ((Comparable) o1).compareTo(o2); }
    };
    public DefaultRowSorter() { }
    protected final void setModelWrapper(ModelWrapper<M, I> modelWrapper) {
        if (modelWrapper == null) throw new IllegalArgumentException("modelWrapper most be non-null");
        ModelWrapper<M, I> last = this.modelWrapper;
        this.modelWrapper = modelWrapper;
        if (last != null) modelStructureChanged();
        else { modelRowCount = getModelWrapper().getRowCount(); }
    }
    protected final ModelWrapper<M, I> getModelWrapper() { return modelWrapper; }
    public final M getModel() { return getModelWrapper().getModel(); }
    public void setSortable(int column, boolean sortable) {
        checkColumn(column);
        if (isSortable == null) {
            isSortable = new boolean[getModelWrapper().getColumnCount()];
            for (int i = isSortable.length - 1; i >= 0; i--) isSortable[i] = true;
        }
        isSortable[column] = sortable;
    }
    public boolean isSortable(int column) {
        checkColumn(column);
        return (isSortable == null) ? true : isSortable[column];
    }
    public void setSortKeys(List<? extends SortKey> sortKeys) {
        List<SortKey> old = this.sortKeys;
        if (sortKeys != null && sortKeys.size() > 0) {
            int max = getModelWrapper().getColumnCount();
            for (SortKey key : sortKeys) {
                if (key == null || key.getColumn() < 0 || key.getColumn() >= max) throw new IllegalArgumentException("Invalid SortKey");
            }
            this.sortKeys = Collections.unmodifiableList(new ArrayList<SortKey>(sortKeys));
        } else {
            this.sortKeys = Collections.emptyList();
        }
        if (!this.sortKeys.equals(old)) {
            fireSortOrderChanged();
            sort();
        }
    }
    public List<? extends SortKey> getSortKeys() { return sortKeys; }
    public void setMaxSortKeys(int max) {
        if (max < 1) throw new IllegalArgumentException("Invalid max");
        maxSortKeys = max;
    }
    public int getMaxSortKeys() { return maxSortKeys; }
    public void setSortsOnUpdates(boolean sortsOnUpdates) { this.sortsOnUpdates = sortsOnUpdates; }
    public boolean getSortsOnUpdates() { return sortsOnUpdates; }
    public void setRowFilter(RowFilter<? super M, ? super I> filter) { this.filter = filter; sort(); }
    public RowFilter<? super M, ? super I> getRowFilter() { return filter; }
    public void toggleSortOrder(int column) {
        checkColumn(column);
        if (isSortable(column)) {
            List<SortKey> keys = new ArrayList<SortKey>(getSortKeys());
            SortKey sortKey;
            int sortIndex;
            for (sortIndex = keys.size() - 1; sortIndex >= 0; sortIndex--) {
                if (keys.get(sortIndex).getColumn() == column) break;
            }
            if (sortIndex == -1) {
                sortKey = new SortKey(column, SortOrder.ASCENDING);
                keys.add(0, sortKey);
            } else if (sortIndex == 0) {
                keys.set(0, toggle(keys.get(0)));
            } else {
                keys.remove(sortIndex);
                keys.add(0, new SortKey(column, SortOrder.ASCENDING));
            }
            if (keys.size() > getMaxSortKeys()) keys = keys.subList(0, getMaxSortKeys());
            setSortKeys(keys);
        }
    }
    private SortKey toggle(SortKey key) {
        if (key.getSortOrder() == SortOrder.ASCENDING) return new SortKey(key.getColumn(), SortOrder.DESCENDING);
        return new SortKey(key.getColumn(), SortOrder.ASCENDING);
    }
    public int convertRowIndexToView(int index) {
        if (modelToView == null) {
            if (index < 0 || index >= getModelWrapper().getRowCount()) throw new IndexOutOfBoundsException("Invalid index");
            return index;
        }
        return modelToView[index];
    }
    public int convertRowIndexToModel(int index) {
        if (viewToModel == null) {
            if (index < 0 || index >= getModelWrapper().getRowCount()) throw new IndexOutOfBoundsException("Invalid index");
            return index;
        }
        return viewToModel[index];
    }
    public int getViewRowCount() { return viewToModel == null ? getModelWrapper().getRowCount() : viewToModel.length; }
    public int getModelRowCount() { return getModelWrapper().getRowCount(); }
    public void setComparator(int column, Comparator<?> comparator) {
        checkColumn(column);
        if (comparators == null) comparators = new Comparator<?>[getModelWrapper().getColumnCount()];
        comparators[column] = comparator;
    }
    public Comparator<?> getComparator(int column) {
        checkColumn(column);
        if (comparators != null) return comparators[column];
        return null;
    }
    public void sort() {
        int[] last = viewToModel;
        int oldCount = last == null ? modelRowCount : last.length;
        int[] lastRowIndexToModel;
        if (last == null) { lastRowIndexToModel = new int[oldCount]; for (int i = 0; i < oldCount; i++) lastRowIndexToModel[i] = i; }
        else lastRowIndexToModel = last;
        final ModelWrapper<M, I> mw = getModelWrapper();
        int n = mw.getRowCount();
        modelRowCount = n;
        boolean unsorted = true;
        for (SortKey k : sortKeys) if (k.getSortOrder() != SortOrder.UNSORTED) unsorted = false;
        ArrayList<Integer> rows = new ArrayList<>();
        if (filter != null) {
            FilterEntry entry = new FilterEntry();
            for (int i = 0; i < n; i++) {
                entry.index = i;
                if (filter.include(entry)) rows.add(i);
            }
        } else for (int i = 0; i < n; i++) rows.add(i);
        if (!unsorted) {
            final ArrayList<SortKey> keys = new ArrayList<>();
            for (SortKey k : sortKeys) if (k.getSortOrder() != SortOrder.UNSORTED) keys.add(k);
            final int nk = keys.size();
            final Comparator[] cmp = new Comparator[nk];
            final boolean[] useToString = new boolean[nk];
            for (int k = 0; k < nk; k++) {
                int col = keys.get(k).getColumn();
                Comparator c = getComparator(col);
                if (c == null) {
                    Class<?> cc = mw.getColumnClass(col);
                    if (cc == String.class) { c = Collator.getInstance(); }
                    else if (Comparable.class.isAssignableFrom(cc)) c = COMPARABLE_COMPARATOR;
                    else { c = Collator.getInstance(); useToString[k] = true; }
                }
                cmp[k] = c;
            }
            // cache des valeurs pour eviter de rappeler le modele
            final Object[][] cache = new Object[nk][n];
            for (int k = 0; k < nk; k++) {
                int col = keys.get(k).getColumn();
                for (int r : rows) {
                    Object v = mw.getValueAt(r, col);
                    if (useToString[k] && v != null) v = mw.getStringValueAt(r, col);
                    cache[k][r] = v;
                }
            }
            Collections.sort(rows, new Comparator<Integer>() {
                @SuppressWarnings("unchecked")
                public int compare(Integer a, Integer b) {
                    for (int k = 0; k < nk; k++) {
                        Object v1 = cache[k][a], v2 = cache[k][b];
                        int result;
                        if (v1 == null) result = v2 == null ? 0 : -1;
                        else if (v2 == null) result = 1;
                        else result = cmp[k].compare(v1, v2);
                        if (keys.get(k).getSortOrder() == SortOrder.DESCENDING) result = -result;
                        if (result != 0) return result;
                    }
                    return a.intValue() - b.intValue();
                }
            });
        }
        if (unsorted && filter == null) {
            viewToModel = null;
            modelToView = null;
        } else {
            viewToModel = new int[rows.size()];
            modelToView = new int[n];
            Arrays.fill(modelToView, -1);
            for (int i = 0; i < viewToModel.length; i++) { viewToModel[i] = rows.get(i); modelToView[viewToModel[i]] = i; }
        }
        fireRowSorterChanged(lastRowIndexToModel);
    }
    private class FilterEntry extends RowFilter.Entry<M, I> {
        int index;
        public M getModel() { return getModelWrapper().getModel(); }
        public int getValueCount() { return getModelWrapper().getColumnCount(); }
        public Object getValue(int column) { return getModelWrapper().getValueAt(index, column); }
        public String getStringValue(int column) { return getModelWrapper().getStringValueAt(index, column); }
        public I getIdentifier() { return getModelWrapper().getIdentifier(index); }
    }
    private void checkColumn(int column) {
        if (column < 0 || column >= getModelWrapper().getColumnCount()) throw new IndexOutOfBoundsException("column beyond range of TableModel");
    }
    public void modelStructureChanged() {
        comparators = null;
        isSortable = null;
        // les cles invalides sont supprimees
        int max = getModelWrapper().getColumnCount();
        boolean bad = false;
        for (SortKey k : sortKeys) if (k.getColumn() >= max) bad = true;
        if (bad) { sortKeys = Collections.emptyList(); fireSortOrderChanged(); }
        sort();
    }
    public void allRowsChanged() { sort(); }
    public void rowsInserted(int firstRow, int endRow) { sort(); }
    public void rowsDeleted(int firstRow, int endRow) { sort(); }
    public void rowsUpdated(int firstRow, int endRow) { if (sortsOnUpdates || filter != null) sort(); else modelRowCount = getModelWrapper().getRowCount(); }
    public void rowsUpdated(int firstRow, int endRow, int column) { if (sortsOnUpdates || filter != null) sort(); else modelRowCount = getModelWrapper().getRowCount(); }
    protected abstract static class ModelWrapper<M, I> {
        protected ModelWrapper() { }
        public abstract M getModel();
        public abstract int getColumnCount();
        public abstract int getRowCount();
        public abstract Object getValueAt(int row, int column);
        public String getStringValueAt(int row, int column) {
            Object o = getValueAt(row, column);
            if (o == null) return "";
            String string = o.toString();
            if (string == null) return "";
            return string;
        }
        public Class<?> getColumnClass(int column) { return Object.class; }
        public abstract I getIdentifier(int row);
    }
}
