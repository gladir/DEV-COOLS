package java.awt;
public class Label extends Component {
    public static final int LEFT = 0, CENTER = 1, RIGHT = 2;
    private String text;
    private int alignment;
    public Label() { this("", LEFT); }
    public Label(String text) { this(text, LEFT); }
    public Label(String text, int alignment) { this.text = text; this.alignment = alignment; }
    public String getText() { return text; }
    public void setText(String t) { text = t; invalidate(); WM.repaint(); }
    public int getAlignment() { return alignment; }
    public void setAlignment(int a) { alignment = a; }
    public Dimension getPreferredSize() { if (prefSize != null) return super.getPreferredSize(); FontMetrics fm = new FontMetrics(getFont()); return new Dimension(fm.stringWidth(text) + 4, fm.getHeight() + 4); }
    public void paint(Graphics g) {
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(getForeground());
        int tw = fm.stringWidth(text);
        int tx = alignment == CENTER ? (width - tw) / 2 : alignment == RIGHT ? width - tw - 2 : 2;
        g.drawString(text, tx, (height - fm.getHeight()) / 2 + fm.getAscent());
    }
}
