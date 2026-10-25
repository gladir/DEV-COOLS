package javax.swing.table;
import java.util.Enumeration;
import javax.swing.*;
import javax.swing.event.*;
public interface TableColumnModel {
    void addColumn(TableColumn aColumn);
    void removeColumn(TableColumn column);
    void moveColumn(int columnIndex, int newIndex);
    void setColumnMargin(int newMargin);
    int getColumnCount();
    Enumeration<TableColumn> getColumns();
    int getColumnIndex(Object columnIdentifier);
    TableColumn getColumn(int columnIndex);
    int getColumnMargin();
    int getColumnIndexAtX(int xPosition);
    int getTotalColumnWidth();
    void setColumnSelectionAllowed(boolean flag);
    boolean getColumnSelectionAllowed();
    int[] getSelectedColumns();
    int getSelectedColumnCount();
    void setSelectionModel(ListSelectionModel newModel);
    ListSelectionModel getSelectionModel();
    void addColumnModelListener(TableColumnModelListener x);
    void removeColumnModelListener(TableColumnModelListener x);
}
