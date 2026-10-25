package javax.swing.border;
import java.awt.*;
public class EmptyBorder extends AbstractBorder {
    protected int left, right, top, bottom;
    public EmptyBorder(int top, int left, int bottom, int right) { this.top = top; this.right = right; this.bottom = bottom; this.left = left; }
    public EmptyBorder(Insets i) { this(i.top, i.left, i.bottom, i.right); }
    public Insets getBorderInsets(Component c) { return new Insets(top, left, bottom, right); }
}
