package javax.swing;
import java.awt.*;
public class JToggleButton extends JButton {
    public JToggleButton() { }
    public JToggleButton(String text) { super(text); }
    public JToggleButton(String text, boolean sel) { super(text); selected = sel; }
    void clicked() { setSelected(!selected); }
    protected void paintComponent(Graphics g) {
        boolean p = pressed;
        pressed = pressed || selected;
        super.paintComponent(g);
        pressed = p;
    }
}
