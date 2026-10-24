package javax.swing.border;
import java.awt.*;
public abstract class AbstractBorder implements Border {
    public void paintBorder(Component c, Graphics g, int x, int y, int width, int height) { }
    public Insets getBorderInsets(Component c) { return new Insets(0, 0, 0, 0); }
    public boolean isBorderOpaque() { return false; }
}
