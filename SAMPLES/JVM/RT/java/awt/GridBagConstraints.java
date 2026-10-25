package java.awt;
public class GridBagConstraints implements Cloneable, java.io.Serializable {
    public static final int RELATIVE = -1;
    public static final int REMAINDER = 0;
    public static final int NONE = 0;
    public static final int BOTH = 1;
    public static final int HORIZONTAL = 2;
    public static final int VERTICAL = 3;
    public static final int CENTER = 10;
    public static final int NORTH = 11;
    public static final int NORTHEAST = 12;
    public static final int EAST = 13;
    public static final int SOUTHEAST = 14;
    public static final int SOUTH = 15;
    public static final int SOUTHWEST = 16;
    public static final int WEST = 17;
    public static final int NORTHWEST = 18;
    public static final int PAGE_START = 19;
    public static final int PAGE_END = 20;
    public static final int LINE_START = 21;
    public static final int LINE_END = 22;
    public static final int FIRST_LINE_START = 23;
    public static final int FIRST_LINE_END = 24;
    public static final int LAST_LINE_START = 25;
    public static final int LAST_LINE_END = 26;
    public static final int BASELINE = 0x100;
    public static final int BASELINE_LEADING = 0x200;
    public static final int BASELINE_TRAILING = 0x300;
    public static final int ABOVE_BASELINE = 0x400;
    public static final int ABOVE_BASELINE_LEADING = 0x500;
    public static final int ABOVE_BASELINE_TRAILING = 0x600;
    public static final int BELOW_BASELINE = 0x700;
    public static final int BELOW_BASELINE_LEADING = 0x800;
    public static final int BELOW_BASELINE_TRAILING = 0x900;
    public int gridx = RELATIVE;
    public int gridy = RELATIVE;
    public int gridwidth = 1;
    public int gridheight = 1;
    public double weightx = 0;
    public double weighty = 0;
    public int anchor = CENTER;
    public int fill = NONE;
    public Insets insets = new Insets(0, 0, 0, 0);
    public int ipadx = 0;
    public int ipady = 0;
    int tempX, tempY, tempWidth, tempHeight, minWidth, minHeight;
    public GridBagConstraints() { }
    public GridBagConstraints(int gridx, int gridy, int gridwidth, int gridheight, double weightx, double weighty, int anchor, int fill, Insets insets, int ipadx, int ipady) {
        this.gridx = gridx; this.gridy = gridy; this.gridwidth = gridwidth; this.gridheight = gridheight;
        this.fill = fill; this.ipadx = ipadx; this.ipady = ipady; this.insets = insets;
        this.anchor = anchor; this.weightx = weightx; this.weighty = weighty;
    }
    public Object clone() {
        try {
            GridBagConstraints c = (GridBagConstraints) super.clone();
            c.insets = (Insets) insets.clone();
            return c;
        } catch (CloneNotSupportedException e) {
            throw new InternalError(e.toString());
        }
    }
}
