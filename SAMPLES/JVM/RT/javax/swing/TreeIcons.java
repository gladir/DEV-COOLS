package javax.swing;
import java.awt.*;
public final class TreeIcons {
    private TreeIcons() { }
    static final Color OUT = new Color(122, 138, 153);
    public static final Icon FOLDER_CLOSED = new Icon() {
        public int getIconWidth() { return 16; }
        public int getIconHeight() { return 16; }
        public void paintIcon(Component c, Graphics g, int x, int y) {
            g.setColor(new Color(200, 218, 238));
            g.fillRect(x + 1, y + 4, 14, 10);
            g.fillRect(x + 1, y + 2, 6, 3);
            g.setColor(Color.WHITE);
            g.drawLine(x + 2, y + 5, x + 13, y + 5);
            g.setColor(OUT);
            g.drawRect(x + 1, y + 4, 14, 10);
            g.drawLine(x + 1, y + 2, x + 6, y + 2);
            g.drawLine(x + 1, y + 2, x + 1, y + 4);
            g.drawLine(x + 6, y + 2, x + 7, y + 4);
        }
    };
    public static final Icon FOLDER_OPEN = new Icon() {
        public int getIconWidth() { return 16; }
        public int getIconHeight() { return 16; }
        public void paintIcon(Component c, Graphics g, int x, int y) {
            g.setColor(new Color(200, 218, 238));
            g.fillRect(x + 1, y + 2, 6, 3);
            g.fillRect(x + 1, y + 4, 11, 3);
            g.setColor(Color.WHITE);
            g.fillPolygon(new int[] { x + 3, x + 15, x + 12, x + 1 }, new int[] { y + 7, y + 7, y + 14, y + 14 }, 4);
            g.setColor(new Color(160, 190, 222));
            g.fillPolygon(new int[] { x + 4, x + 14, x + 12, x + 2 }, new int[] { y + 8, y + 8, y + 13, y + 13 }, 4);
            g.setColor(OUT);
            g.drawLine(x + 1, y + 2, x + 6, y + 2);
            g.drawLine(x + 1, y + 2, x + 1, y + 14);
            g.drawLine(x + 6, y + 2, x + 7, y + 4);
            g.drawLine(x + 7, y + 4, x + 12, y + 4);
            g.drawLine(x + 12, y + 4, x + 12, y + 7);
            g.drawLine(x + 3, y + 7, x + 15, y + 7);
            g.drawLine(x + 15, y + 7, x + 12, y + 14);
            g.drawLine(x + 1, y + 14, x + 12, y + 14);
        }
    };
    public static final Icon LEAF = new Icon() {
        public int getIconWidth() { return 16; }
        public int getIconHeight() { return 16; }
        public void paintIcon(Component c, Graphics g, int x, int y) {
            g.setColor(Color.WHITE);
            g.fillRect(x + 3, y + 1, 10, 14);
            g.setColor(new Color(214, 223, 232));
            g.fillRect(x + 4, y + 2, 8, 12);
            g.setColor(Color.WHITE);
            g.fillRect(x + 4, y + 2, 8, 2);
            g.setColor(OUT);
            g.drawRect(x + 3, y + 1, 9, 13);
            g.drawLine(x + 5, y + 6, x + 10, y + 6);
            g.drawLine(x + 5, y + 8, x + 10, y + 8);
            g.drawLine(x + 5, y + 10, x + 10, y + 10);
        }
    };
    public static final Icon EXPANDED = new Icon() {
        public int getIconWidth() { return 9; }
        public int getIconHeight() { return 9; }
        public void paintIcon(Component c, Graphics g, int x, int y) {
            g.setColor(Color.WHITE);
            g.fillRect(x, y, 9, 9);
            g.setColor(OUT);
            g.drawRect(x, y, 8, 8);
            g.setColor(new Color(51, 51, 51));
            g.drawLine(x + 2, y + 4, x + 6, y + 4);
        }
    };
    public static final Icon COLLAPSED = new Icon() {
        public int getIconWidth() { return 9; }
        public int getIconHeight() { return 9; }
        public void paintIcon(Component c, Graphics g, int x, int y) {
            g.setColor(Color.WHITE);
            g.fillRect(x, y, 9, 9);
            g.setColor(OUT);
            g.drawRect(x, y, 8, 8);
            g.setColor(new Color(51, 51, 51));
            g.drawLine(x + 2, y + 4, x + 6, y + 4);
            g.drawLine(x + 4, y + 2, x + 4, y + 6);
        }
    };
}
