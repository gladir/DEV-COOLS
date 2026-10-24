package javax.swing;
import java.awt.*;
import java.awt.event.*;
public class JFrame extends Frame implements WindowConstants, SwingConstants {
    private JPanel contentPane;
    private JMenuBar menuBar;
    public JFrame() { this(""); }
    public JFrame(String title) {
        super(title);
        closeOp = HIDE_ON_CLOSE;
        contentPane = new JPanel(new BorderLayout());
        super.addImpl(contentPane, "Center", -1);
    }
    public Container getContentPane() { return contentPane; }
    public void setContentPane(Container c) {
        remove(contentPane);
        contentPane = (JPanel) c;
        super.addImpl(contentPane, "Center", -1);
    }
    public JRootPane getRootPane() { return null; }
    public void setJMenuBar(JMenuBar mb) { menuBar = mb; if (mb != null) { super.addImpl(mb, "North", -1); } }
    public JMenuBar getJMenuBar() { return menuBar; }
    protected void addImpl(Component comp, Object constraints, int index) { contentPane.add(comp, constraints, index); }
    public void remove(Component comp) { if (comp == contentPane || comp == menuBar) super.remove(comp); else contentPane.remove(comp); }
    public void setLayout(LayoutManager mgr) { contentPane.setLayout(mgr); }
    public LayoutManager getLayout() { return contentPane.getLayout(); }
    public void setDefaultCloseOperation(int op) { closeOp = op; }
    public int getDefaultCloseOperation() { return closeOp; }
    public void setGlassPane(Component c) { }
    public void setIconImage(Image i) { }
    public void setBackground(Color c) { contentPane.setBackground(c); super.setBackground(c); }
    public void setForeground(Color c) { contentPane.setForeground(c); }
    protected void windowClosingDefault() {
        switch (closeOp) {
            case DISPOSE_ON_CLOSE: dispose(); break;
            case EXIT_ON_CLOSE: System.exit(0); break;
            case HIDE_ON_CLOSE: setVisible(false); break;
            default: break;
        }
    }
    public void paint(Graphics g) { super.paint(g); }
    public String toString() { return getClass().getName() + "[frame" + ",title=" + title + "]"; }
}
