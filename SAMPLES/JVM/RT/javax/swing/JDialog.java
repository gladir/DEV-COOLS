package javax.swing;
import java.awt.*;
public class JDialog extends Dialog implements WindowConstants {
    private JPanel contentPane = new JPanel(new BorderLayout());
    public JDialog() { this((Frame) null, "", false); }
    public JDialog(Frame owner) { this(owner, "", false); }
    public JDialog(Frame owner, String title) { this(owner, title, false); }
    public JDialog(Frame owner, boolean modal) { this(owner, "", modal); }
    public JDialog(Frame owner, String title, boolean modal) { super(owner, title, modal); init(); }
    public JDialog(Window owner, String title, Dialog.ModalityType t) { super(owner, title, t != Dialog.ModalityType.MODELESS); init(); }
    public JDialog(Dialog owner, String title, boolean modal) { super((Window) owner, title, modal); init(); }
    private void init() { closeOp = HIDE_ON_CLOSE; super.addImpl(contentPane, "Center", -1); }
    public Container getContentPane() { return contentPane; }
    protected void addImpl(Component comp, Object constraints, int index) { contentPane.add(comp, constraints, index); }
    public void remove(Component comp) { if (comp == contentPane) super.remove(comp); else contentPane.remove(comp); }
    public void setLayout(LayoutManager mgr) { contentPane.setLayout(mgr); }
    public void setDefaultCloseOperation(int op) { closeOp = op; }
    protected void windowClosingDefault() {
        switch (closeOp) {
            case DISPOSE_ON_CLOSE: dispose(); break;
            case EXIT_ON_CLOSE: System.exit(0); break;
            case HIDE_ON_CLOSE: setVisible(false); break;
            default: break;
        }
    }
}
