package javax.swing;
import java.awt.*;
public class SwingUtilities implements SwingConstants {
    public static void invokeLater(Runnable r) { EventQueue.invokeLater(r); }
    public static void invokeAndWait(Runnable r) { r.run(); }
    public static boolean isEventDispatchThread() { return true; }
    public static Point convertPoint(Component source, Point p, Component dest) {
        Point a = source == null ? new Point(0, 0) : source.getLocationOnScreen();
        Point b = dest == null ? new Point(0, 0) : dest.getLocationOnScreen();
        return new Point(p.x + a.x - b.x, p.y + a.y - b.y);
    }
    public static Window getWindowAncestor(Component c) { return c == null ? null : c.getWindow(); }
    public static void updateComponentTreeUI(Component c) { }
    public static boolean isLeftMouseButton(java.awt.event.MouseEvent e) { return e.getButton() == 1; }
    public static boolean isRightMouseButton(java.awt.event.MouseEvent e) { return e.getButton() == 3; }
}
