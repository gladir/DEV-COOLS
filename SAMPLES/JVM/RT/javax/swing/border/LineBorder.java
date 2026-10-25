package javax.swing.border;
import java.awt.*;
public class LineBorder extends AbstractBorder {
    protected int thickness;
    protected Color lineColor;
    protected boolean roundedCorners;
    public LineBorder(Color color) { this(color, 1, false); }
    public LineBorder(Color color, int thickness) { this(color, thickness, false); }
    public LineBorder(Color color, int thickness, boolean rounded) { lineColor = color; this.thickness = thickness; roundedCorners = rounded; }
    public static Border createBlackLineBorder() { return new LineBorder(Color.black, 1); }
    public static Border createGrayLineBorder() { return new LineBorder(Color.gray, 1); }
    public Color getLineColor() { return lineColor; }
    public int getThickness() { return thickness; }
    public void paintBorder(Component c, Graphics g, int x, int y, int width, int height) {
        Color old = g.getColor();
        g.setColor(lineColor);
        for (int i = 0; i < thickness; i++) g.drawRect(x + i, y + i, width - i - i - 1, height - i - i - 1);
        g.setColor(old);
    }
    public Insets getBorderInsets(Component c) { return new Insets(thickness, thickness, thickness, thickness); }
    public boolean isBorderOpaque() { return !roundedCorners; }
}
