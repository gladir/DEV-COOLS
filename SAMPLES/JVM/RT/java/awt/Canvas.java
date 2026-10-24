package java.awt;
public class Canvas extends Component {
    public Canvas() { }
    public void paint(Graphics g) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); }
}
