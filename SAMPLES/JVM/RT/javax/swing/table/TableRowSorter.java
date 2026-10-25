package javax.swing.table;
import javax.swing.*;
public class TableRowSorter<M extends TableModel> extends DefaultRowSorter<M, Integer> {
    private M tableModel;
    private TableStringConverter stringConverter;
    public TableRowSorter() { this(null); }
    public TableRowSorter(M model) { setModel(model); }
    public void setModel(M model) {
        tableModel = model;
        setModelWrapper(new TableRowSorterModelWrapper());
    }
    public void setStringConverter(TableStringConverter stringConverter) { this.stringConverter = stringConverter; }
    public TableStringConverter getStringConverter() { return stringConverter; }
    private class TableRowSorterModelWrapper extends ModelWrapper<M, Integer> {
        public M getModel() { return tableModel; }
        public int getColumnCount() { return (tableModel == null) ? 0 : tableModel.getColumnCount(); }
        public int getRowCount() { return (tableModel == null) ? 0 : tableModel.getRowCount(); }
        public Object getValueAt(int row, int column) { return tableModel.getValueAt(row, column); }
        public String getStringValueAt(int row, int column) {
            TableStringConverter converter = getStringConverter();
            if (converter != null) {
                String value = converter.toString(tableModel, row, column);
                if (value != null) return value;
                return "";
            }
            return super.getStringValueAt(row, column);
        }
        public Class<?> getColumnClass(int column) { return tableModel.getColumnClass(column); }
        public Integer getIdentifier(int index) { return index; }
    }
}
