package javax.swing.tree;
import java.awt.Component;
import javax.swing.JTree;
public interface TreeCellRenderer {
    Component getTreeCellRendererComponent(JTree tree, Object value, boolean selected, boolean expanded, boolean leaf, int row, boolean hasFocus);
}
