package javax.swing;
public class JCheckBoxMenuItem extends JMenuItem {
    public JCheckBoxMenuItem(String text) { super(text); }
    void clicked() { setSelected(!selected); }
}
