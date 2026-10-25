package java.awt;
public interface ItemSelectable {
    Object[] getSelectedObjects();
    void addItemListener(java.awt.event.ItemListener l);
    void removeItemListener(java.awt.event.ItemListener l);
}
