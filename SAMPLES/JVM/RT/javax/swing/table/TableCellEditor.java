package javax.swing.table;
import java.awt.Component;
import javax.swing.*;
public interface TableCellEditor extends CellEditor {
    Component getTableCellEditorComponent(JTable table, Object value, boolean isSelected, int row, int column);
}
