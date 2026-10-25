package java.awt;
public class Panel extends Container {
    public Panel() { this(new FlowLayout()); }
    public Panel(LayoutManager layout) { setLayout(layout); }
    public void paint(Graphics g) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); super.paint(g); }
}
