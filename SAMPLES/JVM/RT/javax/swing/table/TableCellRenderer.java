package javax.swing.table;
import java.awt.Component;
import javax.swing.JTable;
public interface TableCellRenderer {
    Component getTableCellRendererComponent(JTable table, Object value, boolean isSelected, boolean hasFocus, int row, int column);
}
