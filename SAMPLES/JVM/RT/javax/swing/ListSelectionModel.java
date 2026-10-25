package javax.swing;
import javax.swing.event.*;
public interface ListSelectionModel {
    int SINGLE_SELECTION = 0, SINGLE_INTERVAL_SELECTION = 1, MULTIPLE_INTERVAL_SELECTION = 2;
    void setSelectionInterval(int index0, int index1);
    void addSelectionInterval(int index0, int index1);
    void removeSelectionInterval(int index0, int index1);
    int getMinSelectionIndex();
    int getMaxSelectionIndex();
    boolean isSelectedIndex(int index);
    int getAnchorSelectionIndex();
    void setAnchorSelectionIndex(int index);
    int getLeadSelectionIndex();
    void setLeadSelectionIndex(int index);
    void clearSelection();
    boolean isSelectionEmpty();
    void insertIndexInterval(int index, int length, boolean before);
    void removeIndexInterval(int index0, int index1);
    void setValueIsAdjusting(boolean valueIsAdjusting);
    boolean getValueIsAdjusting();
    void setSelectionMode(int selectionMode);
    int getSelectionMode();
    void addListSelectionListener(ListSelectionListener x);
    void removeListSelectionListener(ListSelectionListener x);
}
