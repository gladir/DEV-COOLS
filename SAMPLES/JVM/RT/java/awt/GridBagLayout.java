package java.awt;
import java.util.Hashtable;
public class GridBagLayout implements LayoutManager2, java.io.Serializable {
    static final int EMPIRICMULTIPLIER = 2;
    protected static final int MAXGRIDSIZE = 512;
    protected static final int MINSIZE = 1;
    protected static final int PREFERREDSIZE = 2;
    protected Hashtable<Component, GridBagConstraints> comptable;
    protected GridBagConstraints defaultConstraints;
    protected GridBagLayoutInfo layoutInfo;
    private Component componentAdjusting;
    public int[] columnWidths;
    public int[] rowHeights;
    public double[] columnWeights;
    public double[] rowWeights;
    protected static class GridBagLayoutInfo implements java.io.Serializable {
        int width, height;
        int startx, starty;
        int[] minWidth, minHeight;
        double[] weightX, weightY;
        boolean hasBaseline;
        short[] baselineType;
        int[] maxAscent, maxDescent;
        boolean hasConstantDescent(int row) { return ((baselineType[row] & (1 << Component.BaselineResizeBehavior.CONSTANT_DESCENT.ordinal())) != 0); }
        boolean hasBaseline(int row) { return (hasBaseline && baselineType[row] != 0); }
        GridBagLayoutInfo(int width, int height) {
            this.width = width; this.height = height;
            minWidth = new int[width]; minHeight = new int[height];
            weightX = new double[width]; weightY = new double[height];
        }
    }
    public GridBagLayout() {
        comptable = new Hashtable<Component, GridBagConstraints>();
        defaultConstraints = new GridBagConstraints();
    }
    public void setConstraints(Component comp, GridBagConstraints constraints) { comptable.put(comp, (GridBagConstraints) constraints.clone()); }
    public GridBagConstraints getConstraints(Component comp) {
        GridBagConstraints constraints = comptable.get(comp);
        if (constraints == null) { setConstraints(comp, defaultConstraints); constraints = comptable.get(comp); }
        return (GridBagConstraints) constraints.clone();
    }
    protected GridBagConstraints lookupConstraints(Component comp) {
        GridBagConstraints constraints = comptable.get(comp);
        if (constraints == null) { setConstraints(comp, defaultConstraints); constraints = comptable.get(comp); }
        return constraints;
    }
    private void removeConstraints(Component comp) { comptable.remove(comp); }
    public Point getLayoutOrigin() {
        Point origin = new Point(0, 0);
        if (layoutInfo != null) { origin.x = layoutInfo.startx; origin.y = layoutInfo.starty; }
        return origin;
    }
    public int[][] getLayoutDimensions() {
        if (layoutInfo == null) return new int[2][0];
        int[][] dim = new int[2][];
        dim[0] = new int[layoutInfo.width];
        dim[1] = new int[layoutInfo.height];
        System.arraycopy(layoutInfo.minWidth, 0, dim[0], 0, layoutInfo.width);
        System.arraycopy(layoutInfo.minHeight, 0, dim[1], 0, layoutInfo.height);
        return dim;
    }
    public double[][] getLayoutWeights() {
        if (layoutInfo == null) return new double[2][0];
        double[][] weights = new double[2][];
        weights[0] = new double[layoutInfo.width];
        weights[1] = new double[layoutInfo.height];
        System.arraycopy(layoutInfo.weightX, 0, weights[0], 0, layoutInfo.width);
        System.arraycopy(layoutInfo.weightY, 0, weights[1], 0, layoutInfo.height);
        return weights;
    }
    public Point location(int x, int y) {
        Point loc = new Point(0, 0);
        int i, d;
        if (layoutInfo == null) return loc;
        d = layoutInfo.startx;
        for (i = 0; i < layoutInfo.width; i++) {
            d += layoutInfo.minWidth[i];
            if (d > x) break;
        }
        loc.x = i;
        d = layoutInfo.starty;
        for (i = 0; i < layoutInfo.height; i++) {
            d += layoutInfo.minHeight[i];
            if (d > y) break;
        }
        loc.y = i;
        return loc;
    }
    public void addLayoutComponent(String name, Component comp) { }
    public void addLayoutComponent(Component comp, Object constraints) {
        if (constraints instanceof GridBagConstraints) setConstraints(comp, (GridBagConstraints) constraints);
        else if (constraints != null) throw new IllegalArgumentException("cannot add to layout: constraints must be a GridBagConstraint");
    }
    public void removeLayoutComponent(Component comp) { removeConstraints(comp); }
    public Dimension preferredLayoutSize(Container parent) {
        GridBagLayoutInfo info = getLayoutInfo(parent, PREFERREDSIZE);
        return getMinSize(parent, info);
    }
    public Dimension minimumLayoutSize(Container parent) {
        GridBagLayoutInfo info = getLayoutInfo(parent, MINSIZE);
        return getMinSize(parent, info);
    }
    public Dimension maximumLayoutSize(Container target) { return new Dimension(Integer.MAX_VALUE, Integer.MAX_VALUE); }
    public float getLayoutAlignmentX(Container parent) { return 0.5f; }
    public float getLayoutAlignmentY(Container parent) { return 0.5f; }
    public void invalidateLayout(Container target) { }
    public void layoutContainer(Container parent) { arrangeGrid(parent); }
    public String toString() { return getClass().getName(); }
    protected GridBagLayoutInfo getLayoutInfo(Container parent, int sizeflag) { return GetLayoutInfo(parent, sizeflag); }
    protected GridBagLayoutInfo GetLayoutInfo(Container parent, int sizeflag) {
        Component comp;
        GridBagConstraints constraints;
        Dimension d;
        Component[] components = parent.getComponents();
        int compindex, i, k, px, py, pixels_diff, nextSize;
        int curX, curY, curWidth, curHeight, curRow, curCol;
        double weight_diff, weight;
        int[] xMaxArray = new int[MAXGRIDSIZE];
        int[] yMaxArray = new int[MAXGRIDSIZE];
        int width = 0, height = 0;
        boolean hasBaseline = false;
        curRow = curCol = -1;
        // Pass #1: dimensions de la grille
        for (compindex = 0; compindex < components.length; compindex++) {
            comp = components[compindex];
            if (!comp.isVisible()) continue;
            constraints = lookupConstraints(comp);
            curX = constraints.gridx;
            curY = constraints.gridy;
            curWidth = constraints.gridwidth;
            if (curWidth <= 0) curWidth = 1;
            curHeight = constraints.gridheight;
            if (curHeight <= 0) curHeight = 1;
            if (curX < 0 && curY < 0) {
                if (curRow >= 0) curY = curRow;
                else if (curCol >= 0) curX = curCol;
                else curY = 0;
            }
            if (curX < 0) {
                px = 0;
                for (i = curY; i < (curY + curHeight); i++) px = Math.max(px, xMaxArray[i]);
                curX = px - curX - 1;
                if (curX < 0) curX = 0;
            } else if (curY < 0) {
                py = 0;
                for (i = curX; i < (curX + curWidth); i++) py = Math.max(py, yMaxArray[i]);
                curY = py - curY - 1;
                if (curY < 0) curY = 0;
            }
            for (px = curX + curWidth; width < px; width++);
            for (py = curY + curHeight; height < py; height++);
            for (i = curX; i < (curX + curWidth); i++) yMaxArray[i] = py;
            for (i = curY; i < (curY + curHeight); i++) xMaxArray[i] = px;
            if (sizeflag == PREFERREDSIZE) d = comp.getPreferredSize();
            else d = comp.getMinimumSize();
            constraints.minWidth = d.width;
            constraints.minHeight = d.height;
            if (calculateBaseline(comp, constraints, d)) hasBaseline = true;
            if (constraints.gridheight == 0 && constraints.gridwidth == 0) curRow = curCol = -1;
            if (constraints.gridheight == 0 && curRow < 0) curCol = curX + curWidth;
            else if (constraints.gridwidth == 0 && curCol < 0) curRow = curY + curHeight;
        }
        if (columnWidths != null && width < columnWidths.length) width = columnWidths.length;
        if (rowHeights != null && height < rowHeights.length) height = rowHeights.length;
        GridBagLayoutInfo r = new GridBagLayoutInfo(width, height);
        // Pass #2: valeurs relatives
        curRow = curCol = -1;
        java.util.Arrays.fill(xMaxArray, 0);
        java.util.Arrays.fill(yMaxArray, 0);
        int[] maxAscent = null, maxDescent = null;
        short[] baselineType = null;
        if (hasBaseline) {
            r.maxAscent = maxAscent = new int[r.height];
            r.maxDescent = maxDescent = new int[r.height];
            r.baselineType = baselineType = new short[r.height];
            r.hasBaseline = true;
        }
        for (compindex = 0; compindex < components.length; compindex++) {
            comp = components[compindex];
            if (!comp.isVisible()) continue;
            constraints = lookupConstraints(comp);
            curX = constraints.gridx;
            curY = constraints.gridy;
            curWidth = constraints.gridwidth;
            curHeight = constraints.gridheight;
            if (curX < 0 && curY < 0) {
                if (curRow >= 0) curY = curRow;
                else if (curCol >= 0) curX = curCol;
                else curY = 0;
            }
            if (curX < 0) {
                if (curHeight <= 0) {
                    curHeight += r.height - curY;
                    if (curHeight < 1) curHeight = 1;
                }
                px = 0;
                for (i = curY; i < (curY + curHeight); i++) px = Math.max(px, xMaxArray[i]);
                curX = px - curX - 1;
                if (curX < 0) curX = 0;
            } else if (curY < 0) {
                if (curWidth <= 0) {
                    curWidth += r.width - curX;
                    if (curWidth < 1) curWidth = 1;
                }
                py = 0;
                for (i = curX; i < (curX + curWidth); i++) py = Math.max(py, yMaxArray[i]);
                curY = py - curY - 1;
                if (curY < 0) curY = 0;
            }
            if (curWidth <= 0) {
                curWidth += r.width - curX;
                if (curWidth < 1) curWidth = 1;
            }
            if (curHeight <= 0) {
                curHeight += r.height - curY;
                if (curHeight < 1) curHeight = 1;
            }
            px = curX + curWidth;
            py = curY + curHeight;
            for (i = curX; i < (curX + curWidth); i++) yMaxArray[i] = py;
            for (i = curY; i < (curY + curHeight); i++) xMaxArray[i] = px;
            if (constraints.gridheight == 0 && constraints.gridwidth == 0) curRow = curCol = -1;
            if (constraints.gridheight == 0 && curRow < 0) curCol = curX + curWidth;
            else if (constraints.gridwidth == 0 && curCol < 0) curRow = curY + curHeight;
            constraints.tempX = curX;
            constraints.tempY = curY;
            constraints.tempWidth = curWidth;
            constraints.tempHeight = curHeight;
            if (hasBaseline) {
                switch (constraints.anchor) {
                    case GridBagConstraints.BASELINE:
                    case GridBagConstraints.BASELINE_LEADING:
                    case GridBagConstraints.BASELINE_TRAILING:
                        if (constraints.ascent >= 0) {
                            if (curHeight == 1) {
                                maxAscent[curY] = Math.max(maxAscent[curY], constraints.ascent);
                                maxDescent[curY] = Math.max(maxDescent[curY], constraints.descent);
                            } else {
                                if (constraints.baselineResizeBehavior == Component.BaselineResizeBehavior.CONSTANT_DESCENT)
                                    maxDescent[curY + curHeight - 1] = Math.max(maxDescent[curY + curHeight - 1], constraints.descent);
                                else maxAscent[curY] = Math.max(maxAscent[curY], constraints.ascent);
                            }
                            if (constraints.baselineResizeBehavior == Component.BaselineResizeBehavior.CONSTANT_DESCENT)
                                baselineType[curY + curHeight - 1] |= (1 << constraints.baselineResizeBehavior.ordinal());
                            else baselineType[curY] |= (1 << constraints.baselineResizeBehavior.ordinal());
                        }
                        break;
                    case GridBagConstraints.ABOVE_BASELINE:
                    case GridBagConstraints.ABOVE_BASELINE_LEADING:
                    case GridBagConstraints.ABOVE_BASELINE_TRAILING:
                        pixels_diff = constraints.minHeight + constraints.insets.top + constraints.ipady;
                        maxAscent[curY] = Math.max(maxAscent[curY], pixels_diff);
                        maxDescent[curY] = Math.max(maxDescent[curY], constraints.insets.bottom);
                        break;
                    case GridBagConstraints.BELOW_BASELINE:
                    case GridBagConstraints.BELOW_BASELINE_LEADING:
                    case GridBagConstraints.BELOW_BASELINE_TRAILING:
                        pixels_diff = constraints.minHeight + constraints.insets.bottom + constraints.ipady;
                        maxDescent[curY] = Math.max(maxDescent[curY], pixels_diff);
                        maxAscent[curY] = Math.max(maxAscent[curY], constraints.insets.top);
                        break;
                }
            }
        }
        if (columnWidths != null) System.arraycopy(columnWidths, 0, r.minWidth, 0, columnWidths.length);
        if (rowHeights != null) System.arraycopy(rowHeights, 0, r.minHeight, 0, rowHeights.length);
        if (columnWeights != null) System.arraycopy(columnWeights, 0, r.weightX, 0, Math.min(r.weightX.length, columnWeights.length));
        if (rowWeights != null) System.arraycopy(rowWeights, 0, r.weightY, 0, Math.min(r.weightY.length, rowWeights.length));
        // Pass #3: distribution des tailles minimales et poids
        nextSize = Integer.MAX_VALUE;
        for (i = 1; i != Integer.MAX_VALUE; i = nextSize, nextSize = Integer.MAX_VALUE) {
            for (compindex = 0; compindex < components.length; compindex++) {
                comp = components[compindex];
                if (!comp.isVisible()) continue;
                constraints = lookupConstraints(comp);
                if (constraints.tempWidth == i) {
                    px = constraints.tempX + constraints.tempWidth;
                    weight_diff = constraints.weightx;
                    for (k = constraints.tempX; k < px; k++) weight_diff -= r.weightX[k];
                    if (weight_diff > 0.0) {
                        weight = 0.0;
                        for (k = constraints.tempX; k < px; k++) weight += r.weightX[k];
                        for (k = constraints.tempX; weight > 0.0 && k < px; k++) {
                            double wt = r.weightX[k];
                            double dx = (wt * weight_diff) / weight;
                            r.weightX[k] += dx;
                            weight_diff -= dx;
                            weight -= wt;
                        }
                        r.weightX[px - 1] += weight_diff;
                    }
                    pixels_diff = constraints.minWidth + constraints.ipadx + constraints.insets.left + constraints.insets.right;
                    for (k = constraints.tempX; k < px; k++) pixels_diff -= r.minWidth[k];
                    if (pixels_diff > 0) {
                        weight = 0.0;
                        for (k = constraints.tempX; k < px; k++) weight += r.weightX[k];
                        for (k = constraints.tempX; weight > 0.0 && k < px; k++) {
                            double wt = r.weightX[k];
                            int dx = (int) ((wt * ((double) pixels_diff)) / weight);
                            r.minWidth[k] += dx;
                            pixels_diff -= dx;
                            weight -= wt;
                        }
                        r.minWidth[px - 1] += pixels_diff;
                    }
                } else if (constraints.tempWidth > i && constraints.tempWidth < nextSize) nextSize = constraints.tempWidth;
                if (constraints.tempHeight == i) {
                    py = constraints.tempY + constraints.tempHeight;
                    weight_diff = constraints.weighty;
                    for (k = constraints.tempY; k < py; k++) weight_diff -= r.weightY[k];
                    if (weight_diff > 0.0) {
                        weight = 0.0;
                        for (k = constraints.tempY; k < py; k++) weight += r.weightY[k];
                        for (k = constraints.tempY; weight > 0.0 && k < py; k++) {
                            double wt = r.weightY[k];
                            double dy = (wt * weight_diff) / weight;
                            r.weightY[k] += dy;
                            weight_diff -= dy;
                            weight -= wt;
                        }
                        r.weightY[py - 1] += weight_diff;
                    }
                    pixels_diff = -1;
                    if (hasBaseline) {
                        switch (constraints.anchor) {
                            case GridBagConstraints.BASELINE:
                            case GridBagConstraints.BASELINE_LEADING:
                            case GridBagConstraints.BASELINE_TRAILING:
                                if (constraints.ascent >= 0) {
                                    if (constraints.tempHeight == 1) pixels_diff = maxAscent[constraints.tempY] + maxDescent[constraints.tempY];
                                    else if (constraints.baselineResizeBehavior != Component.BaselineResizeBehavior.CONSTANT_DESCENT)
                                        pixels_diff = maxAscent[constraints.tempY] + constraints.descent;
                                    else pixels_diff = constraints.ascent + maxDescent[constraints.tempY + constraints.tempHeight - 1];
                                }
                                break;
                            case GridBagConstraints.ABOVE_BASELINE:
                            case GridBagConstraints.ABOVE_BASELINE_LEADING:
                            case GridBagConstraints.ABOVE_BASELINE_TRAILING:
                                pixels_diff = constraints.insets.top + constraints.minHeight + constraints.ipady + maxDescent[constraints.tempY];
                                break;
                            case GridBagConstraints.BELOW_BASELINE:
                            case GridBagConstraints.BELOW_BASELINE_LEADING:
                            case GridBagConstraints.BELOW_BASELINE_TRAILING:
                                pixels_diff = maxAscent[constraints.tempY] + constraints.minHeight + constraints.insets.bottom + constraints.ipady;
                                break;
                        }
                    }
                    if (pixels_diff == -1) pixels_diff = constraints.minHeight + constraints.ipady + constraints.insets.top + constraints.insets.bottom;
                    for (k = constraints.tempY; k < py; k++) pixels_diff -= r.minHeight[k];
                    if (pixels_diff > 0) {
                        weight = 0.0;
                        for (k = constraints.tempY; k < py; k++) weight += r.weightY[k];
                        for (k = constraints.tempY; weight > 0.0 && k < py; k++) {
                            double wt = r.weightY[k];
                            int dy = (int) ((wt * ((double) pixels_diff)) / weight);
                            r.minHeight[k] += dy;
                            pixels_diff -= dy;
                            weight -= wt;
                        }
                        r.minHeight[py - 1] += pixels_diff;
                    }
                } else if (constraints.tempHeight > i && constraints.tempHeight < nextSize) nextSize = constraints.tempHeight;
            }
        }
        return r;
    }
    private boolean calculateBaseline(Component c, GridBagConstraints constraints, Dimension size) {
        int anchor = constraints.anchor;
        if (anchor == GridBagConstraints.BASELINE || anchor == GridBagConstraints.BASELINE_LEADING || anchor == GridBagConstraints.BASELINE_TRAILING) {
            int w = size.width + constraints.ipadx;
            int h = size.height + constraints.ipady;
            constraints.ascent = c.getBaseline(w, h);
            if (constraints.ascent >= 0) {
                int baseline = constraints.ascent;
                constraints.descent = h - constraints.ascent + constraints.insets.bottom;
                constraints.ascent += constraints.insets.top;
                constraints.baselineResizeBehavior = c.getBaselineResizeBehavior();
                constraints.centerPadding = 0;
                if (constraints.baselineResizeBehavior == Component.BaselineResizeBehavior.CENTER_OFFSET) {
                    int nextBaseline = c.getBaseline(w, h + 1);
                    constraints.centerOffset = baseline - h / 2;
                    if (h % 2 == 0) {
                        if (baseline != nextBaseline) constraints.centerPadding = 1;
                    } else if (baseline == nextBaseline) {
                        constraints.centerOffset--;
                        constraints.centerPadding = 1;
                    }
                }
            }
            return true;
        }
        constraints.ascent = -1;
        return false;
    }
    protected Dimension getMinSize(Container parent, GridBagLayoutInfo info) {
        Dimension d = new Dimension();
        int i, t;
        Insets insets = parent.getInsets();
        t = 0;
        for (i = 0; i < info.width; i++) t += info.minWidth[i];
        d.width = t + insets.left + insets.right;
        t = 0;
        for (i = 0; i < info.height; i++) t += info.minHeight[i];
        d.height = t + insets.top + insets.bottom;
        return d;
    }
    protected void arrangeGrid(Container parent) { ArrangeGrid(parent); }
    protected void ArrangeGrid(Container parent) {
        Component comp;
        int compindex;
        GridBagConstraints constraints;
        Insets insets = parent.getInsets();
        Component[] components = parent.getComponents();
        Dimension d;
        Rectangle r = new Rectangle();
        int i, diffw, diffh;
        double weight;
        GridBagLayoutInfo info;
        if (components.length == 0 && (columnWidths == null || columnWidths.length == 0) && (rowHeights == null || rowHeights.length == 0)) return;
        info = getLayoutInfo(parent, PREFERREDSIZE);
        d = getMinSize(parent, info);
        if (parent.width < d.width || parent.height < d.height) {
            info = getLayoutInfo(parent, MINSIZE);
            d = getMinSize(parent, info);
        }
        layoutInfo = info;
        r.width = d.width;
        r.height = d.height;
        diffw = parent.width - r.width;
        if (diffw != 0) {
            weight = 0.0;
            for (i = 0; i < info.width; i++) weight += info.weightX[i];
            if (weight > 0.0) {
                for (i = 0; i < info.width; i++) {
                    int dx = (int) ((((double) diffw) * info.weightX[i]) / weight);
                    info.minWidth[i] += dx;
                    r.width += dx;
                    if (info.minWidth[i] < 0) {
                        r.width -= info.minWidth[i];
                        info.minWidth[i] = 0;
                    }
                }
            }
            diffw = parent.width - r.width;
        } else diffw = 0;
        diffh = parent.height - r.height;
        if (diffh != 0) {
            weight = 0.0;
            for (i = 0; i < info.height; i++) weight += info.weightY[i];
            if (weight > 0.0) {
                for (i = 0; i < info.height; i++) {
                    int dy = (int) ((((double) diffh) * info.weightY[i]) / weight);
                    info.minHeight[i] += dy;
                    r.height += dy;
                    if (info.minHeight[i] < 0) {
                        r.height -= info.minHeight[i];
                        info.minHeight[i] = 0;
                    }
                }
            }
            diffh = parent.height - r.height;
        } else diffh = 0;
        info.startx = diffw / 2 + insets.left;
        info.starty = diffh / 2 + insets.top;
        for (compindex = 0; compindex < components.length; compindex++) {
            comp = components[compindex];
            if (!comp.isVisible()) continue;
            constraints = lookupConstraints(comp);
            r.x = info.startx;
            for (i = 0; i < constraints.tempX; i++) r.x += info.minWidth[i];
            r.y = info.starty;
            for (i = 0; i < constraints.tempY; i++) r.y += info.minHeight[i];
            r.width = 0;
            for (i = constraints.tempX; i < (constraints.tempX + constraints.tempWidth); i++) r.width += info.minWidth[i];
            r.height = 0;
            for (i = constraints.tempY; i < (constraints.tempY + constraints.tempHeight); i++) r.height += info.minHeight[i];
            componentAdjusting = comp;
            adjustForGravity(constraints, r);
            if (r.x < 0) { r.width += r.x; r.x = 0; }
            if (r.y < 0) { r.height += r.y; r.y = 0; }
            if ((r.width <= 0) || (r.height <= 0)) {
                comp.setBounds(0, 0, 0, 0);
            } else {
                if (comp.x != r.x || comp.y != r.y || comp.width != r.width || comp.height != r.height) comp.setBounds(r.x, r.y, r.width, r.height);
            }
        }
    }
    protected void adjustForGravity(GridBagConstraints constraints, Rectangle r) { AdjustForGravity(constraints, r); }
    protected void AdjustForGravity(GridBagConstraints constraints, Rectangle r) {
        int diffx, diffy;
        int cellY = r.y;
        int cellHeight = r.height;
        r.x += constraints.insets.left;
        r.width -= (constraints.insets.left + constraints.insets.right);
        r.y += constraints.insets.top;
        r.height -= (constraints.insets.top + constraints.insets.bottom);
        diffx = 0;
        if ((constraints.fill != GridBagConstraints.HORIZONTAL && constraints.fill != GridBagConstraints.BOTH) && (r.width > (constraints.minWidth + constraints.ipadx))) {
            diffx = r.width - (constraints.minWidth + constraints.ipadx);
            r.width = constraints.minWidth + constraints.ipadx;
        }
        diffy = 0;
        if ((constraints.fill != GridBagConstraints.VERTICAL && constraints.fill != GridBagConstraints.BOTH) && (r.height > (constraints.minHeight + constraints.ipady))) {
            diffy = r.height - (constraints.minHeight + constraints.ipady);
            r.height = constraints.minHeight + constraints.ipady;
        }
        switch (constraints.anchor) {
            case GridBagConstraints.BASELINE:
                r.x += diffx / 2;
                alignOnBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.BASELINE_LEADING:
                alignOnBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.BASELINE_TRAILING:
                r.x += diffx;
                alignOnBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.ABOVE_BASELINE:
                r.x += diffx / 2;
                alignAboveBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.ABOVE_BASELINE_LEADING:
                alignAboveBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.ABOVE_BASELINE_TRAILING:
                r.x += diffx;
                alignAboveBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.BELOW_BASELINE:
                r.x += diffx / 2;
                alignBelowBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.BELOW_BASELINE_LEADING:
                alignBelowBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.BELOW_BASELINE_TRAILING:
                r.x += diffx;
                alignBelowBaseline(constraints, r, cellY, cellHeight);
                break;
            case GridBagConstraints.CENTER:
                r.x += diffx / 2;
                r.y += diffy / 2;
                break;
            case GridBagConstraints.PAGE_START:
            case GridBagConstraints.NORTH:
                r.x += diffx / 2;
                break;
            case GridBagConstraints.NORTHEAST:
                r.x += diffx;
                break;
            case GridBagConstraints.EAST:
                r.x += diffx;
                r.y += diffy / 2;
                break;
            case GridBagConstraints.SOUTHEAST:
                r.x += diffx;
                r.y += diffy;
                break;
            case GridBagConstraints.PAGE_END:
            case GridBagConstraints.SOUTH:
                r.x += diffx / 2;
                r.y += diffy;
                break;
            case GridBagConstraints.SOUTHWEST:
                r.y += diffy;
                break;
            case GridBagConstraints.WEST:
                r.y += diffy / 2;
                break;
            case GridBagConstraints.NORTHWEST:
                break;
            case GridBagConstraints.LINE_START:
                r.y += diffy / 2;
                break;
            case GridBagConstraints.LINE_END:
                r.x += diffx;
                r.y += diffy / 2;
                break;
            case GridBagConstraints.FIRST_LINE_START:
                break;
            case GridBagConstraints.FIRST_LINE_END:
                r.x += diffx;
                break;
            case GridBagConstraints.LAST_LINE_START:
                r.y += diffy;
                break;
            case GridBagConstraints.LAST_LINE_END:
                r.x += diffx;
                r.y += diffy;
                break;
            default:
                throw new IllegalArgumentException("illegal anchor value");
        }
    }
    private void alignOnBaseline(GridBagConstraints cons, Rectangle r, int cellY, int cellHeight) {
        if (cons.ascent >= 0) {
            if (cons.baselineResizeBehavior == Component.BaselineResizeBehavior.CONSTANT_DESCENT) {
                int maxY = cellY + cellHeight - layoutInfo.maxDescent[cons.tempY + cons.tempHeight - 1] + cons.descent - cons.insets.bottom;
                if (!cons.isVerticallyResizable()) {
                    r.y = maxY - cons.minHeight;
                    r.height = cons.minHeight;
                } else {
                    r.height = maxY - cellY - cons.insets.top;
                }
            } else {
                int baseline;
                int ascent = cons.ascent;
                if (layoutInfo.hasConstantDescent(cons.tempY)) baseline = cellHeight - layoutInfo.maxDescent[cons.tempY];
                else baseline = layoutInfo.maxAscent[cons.tempY];
                if (cons.baselineResizeBehavior == Component.BaselineResizeBehavior.OTHER) {
                    boolean fits = false;
                    ascent = componentAdjusting.getBaseline(r.width, r.height);
                    if (ascent >= 0) ascent += cons.insets.top;
                    if (ascent >= 0 && ascent <= baseline) {
                        if (baseline + (r.height - ascent - cons.insets.top) <= cellHeight - cons.insets.bottom) {
                            fits = true;
                        } else if (cons.isVerticallyResizable()) {
                            int ascent2 = componentAdjusting.getBaseline(r.width, cellHeight - cons.insets.bottom - baseline + ascent);
                            if (ascent2 >= 0) ascent2 += cons.insets.top;
                            if (ascent2 >= 0 && ascent2 <= ascent) {
                                r.height = cellHeight - cons.insets.bottom - baseline + ascent;
                                ascent = ascent2;
                                fits = true;
                            }
                        }
                    }
                    if (!fits) {
                        ascent = cons.ascent;
                        r.width = cons.minWidth;
                        r.height = cons.minHeight;
                    }
                }
                r.y = cellY + baseline - ascent + cons.insets.top;
                if (cons.isVerticallyResizable()) {
                    switch (cons.baselineResizeBehavior) {
                        case CONSTANT_ASCENT:
                            r.height = Math.max(cons.minHeight, cellY + cellHeight - r.y - cons.insets.bottom);
                            break;
                        case CENTER_OFFSET: {
                            int upper = r.y - cellY - cons.insets.top;
                            int lower = cellY + cellHeight - r.y - cons.minHeight - cons.insets.bottom;
                            int delta = Math.min(upper, lower);
                            delta += delta;
                            if (delta > 0 && (cons.minHeight + cons.centerPadding + delta) / 2 + cons.centerOffset != baseline) delta--;
                            r.height = cons.minHeight + delta;
                            r.y = cellY + baseline - (r.height + cons.centerPadding) / 2 - cons.centerOffset;
                            break;
                        }
                        default:
                            break;
                    }
                }
            }
        } else {
            centerVertically(cons, r, cellHeight);
        }
    }
    private void alignAboveBaseline(GridBagConstraints cons, Rectangle r, int cellY, int cellHeight) {
        if (layoutInfo.hasBaseline(cons.tempY)) {
            int maxY;
            if (layoutInfo.hasConstantDescent(cons.tempY)) maxY = cellY + cellHeight - layoutInfo.maxDescent[cons.tempY];
            else maxY = cellY + layoutInfo.maxAscent[cons.tempY];
            if (cons.isVerticallyResizable()) {
                r.y = cellY + cons.insets.top;
                r.height = maxY - r.y;
            } else {
                r.height = cons.minHeight + cons.ipady;
                r.y = maxY - r.height;
            }
        } else {
            centerVertically(cons, r, cellHeight);
        }
    }
    private void alignBelowBaseline(GridBagConstraints cons, Rectangle r, int cellY, int cellHeight) {
        if (layoutInfo.hasBaseline(cons.tempY)) {
            if (layoutInfo.hasConstantDescent(cons.tempY)) r.y = cellY + cellHeight - layoutInfo.maxDescent[cons.tempY];
            else r.y = cellY + layoutInfo.maxAscent[cons.tempY];
            if (cons.isVerticallyResizable()) r.height = cellY + cellHeight - r.y - cons.insets.bottom;
        } else {
            centerVertically(cons, r, cellHeight);
        }
    }
    private void centerVertically(GridBagConstraints cons, Rectangle r, int cellHeight) {
        if (!cons.isVerticallyResizable()) {
            r.y += Math.max(0, (cellHeight - cons.insets.top - cons.insets.bottom - cons.minHeight - cons.ipady) / 2);
        }
    }
}
