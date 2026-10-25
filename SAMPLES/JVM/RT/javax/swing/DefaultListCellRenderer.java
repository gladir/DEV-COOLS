package javax.swing;
import java.awt.*;
import javax.swing.border.*;
public class DefaultListCellRenderer extends JLabel implements ListCellRenderer<Object>, java.io.Serializable {
    protected static Border noFocusBorder = new EmptyBorder(3, 3, 3, 3);
    static final Border focusBorder = new CompoundBorder(new LineBorder(new Color(99, 130, 191)), new EmptyBorder(2, 2, 2, 2));
    public DefaultListCellRenderer() { opaque = true; setBorder(noFocusBorder); }
    public Component getListCellRendererComponent(JList<?> list, Object value, int index, boolean isSelected, boolean cellHasFocus) {
        if (isSelected) { setBackground(list.getSelectionBackground()); setForeground(list.getSelectionForeground()); }
        else { setBackground(list.getBackground()); setForeground(list.getForeground()); }
        if (value instanceof Icon) { setIcon((Icon) value); setText(""); }
        else { setIcon(null); setText(value == null ? "" : value.toString()); }
        setEnabled(list.isEnabled());
        setFont(list.getFont());
        setBorder(cellHasFocus ? focusBorder : noFocusBorder);
        return this;
    }
    public static class UIResource extends DefaultListCellRenderer { }
}
