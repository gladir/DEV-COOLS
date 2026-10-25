package javax.swing;
import javax.swing.event.*;
public interface SingleSelectionModel {
    int getSelectedIndex();
    void setSelectedIndex(int index);
    void clearSelection();
    boolean isSelected();
    void addChangeListener(ChangeListener listener);
    void removeChangeListener(ChangeListener listener);
}
