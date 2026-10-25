package javax.swing.table;
import java.awt.*;
import javax.swing.*;
import javax.swing.border.*;
public class DefaultTableCellRenderer extends JLabel implements TableCellRenderer, java.io.Serializable {
    private static final Border SAFE_NO_FOCUS_BORDER = new EmptyBorder(1, 3, 1, 3);
    protected static Border noFocusBorder = new EmptyBorder(1, 3, 1, 3);
    static final Border focusBorder = new LineBorder(new Color(115, 164, 209));
    private Color unselectedForeground;
    private Color unselectedBackground;
    public DefaultTableCellRenderer() {
        super();
        setOpaque(true);
        setBorder(getNoFocusBorder());
    }
    private Border getNoFocusBorder() { return noFocusBorder; }
    public void setForeground(Color c) { super.setForeground(c); unselectedForeground = c; }
    public void setBackground(Color c) { super.setBackground(c); unselectedBackground = c; }
    public Component getTableCellRendererComponent(JTable table, Object value, boolean isSelected, boolean hasFocus, int row, int column) {
        if (table == null) return this;
        Color fg = null;
        Color bg = null;
        if (isSelected) {
            super.setForeground(fg == null ? table.getSelectionForeground() : fg);
            super.setBackground(bg == null ? table.getSelectionBackground() : bg);
        } else {
            Color background = unselectedBackground != null ? unselectedBackground : table.getBackground();
            super.setForeground(unselectedForeground != null ? unselectedForeground : table.getForeground());
            super.setBackground(background);
        }
        setFont(table.getFont());
        if (hasFocus) setBorder(focusBorder);
        else setBorder(getNoFocusBorder());
        setValue(value);
        return this;
    }
    protected void setValue(Object value) { setText((value == null) ? "" : value.toString()); }
    public static class UIResource extends DefaultTableCellRenderer implements javax.swing.plaf.UIResource { }
}
