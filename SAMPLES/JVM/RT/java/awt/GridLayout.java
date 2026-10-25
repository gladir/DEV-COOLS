package java.awt;
public class GridLayout implements LayoutManager, java.io.Serializable {
    int hgap, vgap, rows, cols;
    public GridLayout() { this(1, 0, 0, 0); }
    public GridLayout(int rows, int cols) { this(rows, cols, 0, 0); }
    public GridLayout(int rows, int cols, int hgap, int vgap) {
        if ((rows == 0) && (cols == 0)) throw new IllegalArgumentException("rows and cols cannot both be zero");
        this.rows = rows; this.cols = cols; this.hgap = hgap; this.vgap = vgap;
    }
    public int getRows() { return rows; }
    public int getColumns() { return cols; }
    public void setRows(int r) { rows = r; }
    public void setColumns(int c) { cols = c; }
    public int getHgap() { return hgap; }
    public int getVgap() { return vgap; }
    public void setHgap(int h) { hgap = h; }
    public void setVgap(int v) { vgap = v; }
    public void addLayoutComponent(String name, Component comp) { }
    public void removeLayoutComponent(Component comp) { }
    public Dimension preferredLayoutSize(Container parent) {
        Insets insets = parent.getInsets();
        int ncomponents = parent.getComponentCount();
        int nrows = rows, ncols = cols;
        if (nrows > 0) ncols = (ncomponents + nrows - 1) / nrows; else nrows = (ncomponents + ncols - 1) / ncols;
        int w = 0, h = 0;
        for (int i = 0; i < ncomponents; i++) {
            Dimension d = parent.getComponent(i).getPreferredSize();
            if (w < d.width) w = d.width;
            if (h < d.height) h = d.height;
        }
        return new Dimension(insets.left + insets.right + ncols * w + (ncols - 1) * hgap, insets.top + insets.bottom + nrows * h + (nrows - 1) * vgap);
    }
    public Dimension minimumLayoutSize(Container parent) { return preferredLayoutSize(parent); }
    public void layoutContainer(Container parent) {
        Insets insets = parent.getInsets();
        int ncomponents = parent.getComponentCount();
        int nrows = rows, ncols = cols;
        if (ncomponents == 0) return;
        if (nrows > 0) ncols = (ncomponents + nrows - 1) / nrows; else nrows = (ncomponents + ncols - 1) / ncols;
        int totalGapsWidth = (ncols - 1) * hgap;
        int widthWOInsets = parent.getWidth() - (insets.left + insets.right);
        int widthOnComponent = (widthWOInsets - totalGapsWidth) / ncols;
        int extraWidthAvailable = (widthWOInsets - (widthOnComponent * ncols + totalGapsWidth)) / 2;
        int totalGapsHeight = (nrows - 1) * vgap;
        int heightWOInsets = parent.getHeight() - (insets.top + insets.bottom);
        int heightOnComponent = (heightWOInsets - totalGapsHeight) / nrows;
        int extraHeightAvailable = (heightWOInsets - (heightOnComponent * nrows + totalGapsHeight)) / 2;
        for (int c = 0, x = insets.left + extraWidthAvailable; c < ncols; c++, x += widthOnComponent + hgap) {
            for (int r = 0, y = insets.top + extraHeightAvailable; r < nrows; r++, y += heightOnComponent + vgap) {
                int i = r * ncols + c;
                if (i < ncomponents) parent.getComponent(i).setBounds(x, y, widthOnComponent, heightOnComponent);
            }
        }
    }
    public String toString() { return getClass().getName() + "[hgap=" + hgap + ",vgap=" + vgap + ",rows=" + rows + ",cols=" + cols + "]"; }
}
