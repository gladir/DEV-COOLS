package javax.swing.tree;
import java.awt.*;
import java.awt.event.*;
import java.util.EventObject;
import javax.swing.*;
import javax.swing.border.*;
import javax.swing.event.*;
public class DefaultTreeCellEditor implements ActionListener, TreeCellEditor, TreeSelectionListener {
    protected TreeCellEditor realEditor;
    protected DefaultTreeCellRenderer renderer;
    protected Container editingContainer;
    protected transient Component editingComponent;
    protected boolean canEdit;
    protected transient int offset;
    protected transient JTree tree;
    protected transient TreePath lastPath;
    protected transient Timer timer;
    protected transient int lastRow;
    protected Color borderSelectionColor;
    protected transient Icon editingIcon;
    protected Font font;
    public DefaultTreeCellEditor(JTree tree, DefaultTreeCellRenderer renderer) { this(tree, renderer, null); }
    public DefaultTreeCellEditor(JTree tree, DefaultTreeCellRenderer renderer, TreeCellEditor editor) {
        this.renderer = renderer;
        realEditor = editor;
        if (realEditor == null) realEditor = createTreeCellEditor();
        editingContainer = createContainer();
        setTree(tree);
        setBorderSelectionColor(new Color(115, 164, 209));
    }
    public void setBorderSelectionColor(Color newColor) { borderSelectionColor = newColor; }
    public Color getBorderSelectionColor() { return borderSelectionColor; }
    public void setFont(Font font) { this.font = font; }
    public Font getFont() { return font; }
    public Component getTreeCellEditorComponent(JTree tree, Object value, boolean isSelected, boolean expanded, boolean leaf, int row) {
        setTree(tree);
        lastRow = row;
        determineOffset(tree, value, isSelected, expanded, leaf, row);
        if (editingComponent != null) editingContainer.remove(editingComponent);
        editingComponent = realEditor.getTreeCellEditorComponent(tree, value, isSelected, expanded, leaf, row);
        TreePath newPath = tree.getPathForRow(row);
        canEdit = (lastPath != null && newPath != null && lastPath.equals(newPath));
        Font font = getFont();
        if (font == null) {
            if (renderer != null) font = renderer.getFont();
            if (font == null) font = tree.getFont();
        }
        editingContainer.setFont(font);
        prepareForEditing();
        return editingContainer;
    }
    public Object getCellEditorValue() { return realEditor.getCellEditorValue(); }
    public boolean isCellEditable(EventObject event) {
        if (event != null && event instanceof MouseEvent) {
            MouseEvent me = (MouseEvent) event;
            if (me.getClickCount() < 2) return false;
        }
        return realEditor.isCellEditable(event);
    }
    public boolean shouldSelectCell(EventObject event) { return realEditor.shouldSelectCell(event); }
    public boolean stopCellEditing() {
        if (realEditor.stopCellEditing()) { cleanupAfterEditing(); return true; }
        return false;
    }
    public void cancelCellEditing() { realEditor.cancelCellEditing(); cleanupAfterEditing(); }
    public void addCellEditorListener(CellEditorListener l) { realEditor.addCellEditorListener(l); }
    public void removeCellEditorListener(CellEditorListener l) { realEditor.removeCellEditorListener(l); }
    public CellEditorListener[] getCellEditorListeners() { return ((DefaultCellEditor) realEditor).getCellEditorListeners(); }
    public void valueChanged(TreeSelectionEvent e) {
        if (tree != null) {
            if (tree.getSelectionCount() == 1) lastPath = tree.getSelectionPath();
            else lastPath = null;
        }
        if (timer != null) timer.stop();
    }
    public void actionPerformed(ActionEvent e) {
        if (tree != null && lastPath != null) tree.startEditingAtPath(lastPath);
    }
    protected void setTree(JTree newTree) {
        if (tree != newTree) {
            if (tree != null) tree.removeTreeSelectionListener(this);
            tree = newTree;
            if (tree != null) tree.addTreeSelectionListener(this);
            if (timer != null) timer.stop();
        }
    }
    protected boolean shouldStartEditingTimer(EventObject event) {
        if ((event instanceof MouseEvent) && SwingUtilities.isLeftMouseButton((MouseEvent) event)) {
            MouseEvent me = (MouseEvent) event;
            return (me.getClickCount() == 1 && inHitRegion(me.getX(), me.getY()));
        }
        return false;
    }
    protected void startEditingTimer() {
        if (timer == null) {
            timer = new Timer(1200, this);
            timer.setRepeats(false);
        }
        timer.start();
    }
    protected boolean canEditImmediately(EventObject event) {
        if ((event instanceof MouseEvent) && SwingUtilities.isLeftMouseButton((MouseEvent) event)) {
            MouseEvent me = (MouseEvent) event;
            return ((me.getClickCount() > 2) && inHitRegion(me.getX(), me.getY()));
        }
        return (event == null);
    }
    protected boolean inHitRegion(int x, int y) {
        if (lastRow != -1 && tree != null) {
            Rectangle bounds = tree.getRowBounds(lastRow);
            if (bounds != null) return bounds.contains(x, y);
        }
        return true;
    }
    protected void determineOffset(JTree tree, Object value, boolean isSelected, boolean expanded, boolean leaf, int row) {
        if (renderer != null) {
            if (leaf) editingIcon = renderer.getLeafIcon();
            else if (expanded) editingIcon = renderer.getOpenIcon();
            else editingIcon = renderer.getClosedIcon();
            if (editingIcon != null) offset = renderer.getIconTextGap() + editingIcon.getIconWidth();
            else offset = renderer.getIconTextGap();
        } else {
            editingIcon = null;
            offset = 0;
        }
    }
    protected void prepareForEditing() {
        if (editingComponent != null) editingContainer.add(editingComponent);
    }
    protected Container createContainer() { return new EditorContainer(); }
    protected TreeCellEditor createTreeCellEditor() {
        JTextField aField = new JTextField() {
            public Insets getInsets() { return new Insets(1, 2, 1, 2); }
        };
        DefaultCellEditor editor = new DefaultCellEditor(aField);
        editor.setClickCountToStart(1);
        return editor;
    }
    private void cleanupAfterEditing() {
        if (editingComponent != null) editingContainer.remove(editingComponent);
        editingComponent = null;
    }
    public class EditorContainer extends Container {
        public EditorContainer() { setLayout(null); }
        public void doLayout() {
            if (editingComponent != null) {
                int cWidth = getWidth();
                int cHeight = getHeight();
                if (editingIcon != null) {
                    int iconHeight = editingIcon.getIconHeight();
                    int textH = editingComponent.getPreferredSize().height;
                    editingComponent.setBounds(offset, Math.max(0, (cHeight - textH) / 2), cWidth - offset, Math.min(cHeight, textH));
                } else editingComponent.setBounds(0, 0, cWidth, cHeight);
            }
        }
        public Dimension getPreferredSize() {
            if (editingComponent != null) {
                Dimension pSize = editingComponent.getPreferredSize();
                pSize.width += offset + 5;
                Dimension rSize = (renderer != null) ? renderer.getPreferredSize() : null;
                if (rSize != null) pSize.height = Math.max(pSize.height, rSize.height);
                if (editingIcon != null) pSize.height = Math.max(pSize.height, editingIcon.getIconHeight());
                pSize.width = Math.max(pSize.width, 100);
                return pSize;
            }
            return new Dimension(0, 0);
        }
        public void paint(Graphics g) {
            Dimension size = getSize();
            if (editingIcon != null) {
                int yLoc = Math.max(0, (size.height - editingIcon.getIconHeight()) / 2);
                editingIcon.paintIcon(this, g, 0, yLoc);
            }
            super.paint(g);
        }
    }
}
