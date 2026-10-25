package javax.swing.tree;
import java.awt.Component;
import javax.swing.CellEditor;
import javax.swing.JTree;
public interface TreeCellEditor extends CellEditor {
    Component getTreeCellEditorComponent(JTree tree, Object value, boolean isSelected, boolean expanded, boolean leaf, int row);
}
