package javax.swing;
import java.awt.*;
public class Box extends JPanel {
    public Box(int axis) { super(null); setLayout(new BoxLayout(this, axis)); opaque = false; }
    public static Box createHorizontalBox() { return new Box(BoxLayout.X_AXIS); }
    public static Box createVerticalBox() { return new Box(BoxLayout.Y_AXIS); }
    public static Component createHorizontalStrut(int w) { return new Filler(new Dimension(w, 0), false); }
    public static Component createVerticalStrut(int h) { return new Filler(new Dimension(0, h), false); }
    public static Component createRigidArea(Dimension d) { return new Filler(d, false); }
    public static Component createHorizontalGlue() { return new Filler(new Dimension(0, 0), true); }
    public static Component createVerticalGlue() { return new Filler(new Dimension(0, 0), true); }
    public static class Filler extends JComponent {
        boolean glue;
        Filler(Dimension d, boolean glue) { setPreferredSize(d); this.glue = glue; }
    }
}
