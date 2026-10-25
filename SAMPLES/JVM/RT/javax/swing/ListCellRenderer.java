package javax.swing;
import java.awt.Component;
public interface ListCellRenderer<E> {
    Component getListCellRendererComponent(JList<? extends E> list, E value, int index, boolean isSelected, boolean cellHasFocus);
}
