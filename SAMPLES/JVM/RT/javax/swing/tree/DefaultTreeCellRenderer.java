package javax.swing.tree;
import java.awt.*;
import javax.swing.*;
import javax.swing.border.EmptyBorder;
public class DefaultTreeCellRenderer extends JLabel implements TreeCellRenderer {
    private JTree tree;
    protected boolean selected;
    protected boolean hasFocus;
    private boolean drawsFocusBorderAroundIcon;
    private boolean drawDashedFocusIndicator;
    private Color treeBGColor;
    private Color focusBGColor;
    protected transient Icon closedIcon;
    protected transient Icon leafIcon;
    protected transient Icon openIcon;
    protected Color textSelectionColor;
    protected Color textNonSelectionColor;
    protected Color backgroundSelectionColor;
    protected Color backgroundNonSelectionColor;
    protected Color borderSelectionColor;
    private boolean isDropCell;
    private boolean fillBackground = true;
    public DefaultTreeCellRenderer() {
        setHorizontalAlignment(LEFT);
        setLeafIcon(TreeIcons.LEAF);
        setClosedIcon(TreeIcons.FOLDER_CLOSED);
        setOpenIcon(TreeIcons.FOLDER_OPEN);
        setTextSelectionColor(new Color(51, 51, 51));
        setTextNonSelectionColor(new Color(51, 51, 51));
        setBackgroundSelectionColor(new Color(184, 207, 229));
        setBackgroundNonSelectionColor(Color.WHITE);
        setBorderSelectionColor(new Color(115, 164, 209));
        drawsFocusBorderAroundIcon = false;
        drawDashedFocusIndicator = false;
        setBorder(new EmptyBorder(1, 2, 1, 2));
        setOpaque(false);
    }
    public Icon getDefaultOpenIcon() { return TreeIcons.FOLDER_OPEN; }
    public Icon getDefaultClosedIcon() { return TreeIcons.FOLDER_CLOSED; }
    public Icon getDefaultLeafIcon() { return TreeIcons.LEAF; }
    public void setOpenIcon(Icon newIcon) { openIcon = newIcon; }
    public Icon getOpenIcon() { return openIcon; }
    public void setClosedIcon(Icon newIcon) { closedIcon = newIcon; }
    public Icon getClosedIcon() { return closedIcon; }
    public void setLeafIcon(Icon newIcon) { leafIcon = newIcon; }
    public Icon getLeafIcon() { return leafIcon; }
    public void setTextSelectionColor(Color newColor) { textSelectionColor = newColor; }
    public Color getTextSelectionColor() { return textSelectionColor; }
    public void setTextNonSelectionColor(Color newColor) { textNonSelectionColor = newColor; }
    public Color getTextNonSelectionColor() { return textNonSelectionColor; }
    public void setBackgroundSelectionColor(Color newColor) { backgroundSelectionColor = newColor; }
    public Color getBackgroundSelectionColor() { return backgroundSelectionColor; }
    public void setBackgroundNonSelectionColor(Color newColor) { backgroundNonSelectionColor = newColor; }
    public Color getBackgroundNonSelectionColor() { return backgroundNonSelectionColor; }
    public void setBorderSelectionColor(Color newColor) { borderSelectionColor = newColor; }
    public Color getBorderSelectionColor() { return borderSelectionColor; }
    public Component getTreeCellRendererComponent(JTree tree, Object value, boolean sel, boolean expanded, boolean leaf, int row, boolean hasFocus) {
        String stringValue = tree.convertValueToText(value, sel, expanded, leaf, row, hasFocus);
        this.tree = tree;
        this.hasFocus = hasFocus;
        setText(stringValue);
        Color fg = null;
        if (sel) fg = getTextSelectionColor();
        else fg = getTextNonSelectionColor();
        setForeground(fg);
        Icon icon = null;
        if (leaf) icon = getLeafIcon();
        else if (expanded) icon = getOpenIcon();
        else icon = getClosedIcon();
        if (!tree.isEnabled()) { setEnabled(false); setIcon(icon); }
        else { setEnabled(true); setIcon(icon); }
        selected = sel;
        return this;
    }
    public void paint(Graphics g) {
        Color bColor;
        if (selected) bColor = getBackgroundSelectionColor();
        else {
            bColor = getBackgroundNonSelectionColor();
            if (bColor == null) bColor = getBackground();
        }
        int imageOffset = -1;
        if (bColor != null) {
            imageOffset = getLabelStart();
            g.setColor(bColor);
            g.fillRect(imageOffset, 0, getWidth() - imageOffset, getHeight());
        }
        if (hasFocus) {
            if (imageOffset < 0) imageOffset = getLabelStart();
            g.setColor(getBorderSelectionColor());
            g.drawRect(imageOffset, 0, getWidth() - imageOffset - 1, getHeight() - 1);
        }
        super.paint(g);
    }
    private int getLabelStart() {
        Icon currentI = getIcon();
        Insets in = getInsets();
        if (currentI != null && getText() != null && getText().length() > 0) return in.left + currentI.getIconWidth() + 4 - 2;
        return 0;
    }
    public Dimension getPreferredSize() {
        Dimension retDimension = super.getPreferredSize();
        if (retDimension != null) retDimension = new Dimension(retDimension.width + 3, retDimension.height);
        return retDimension;
    }
    public void validate() { }
    public void invalidate() { }
    public void revalidate() { }
    public void repaint(long tm, int x, int y, int width, int height) { }
    public void repaint(Rectangle r) { }
    public void repaint() { }
}
