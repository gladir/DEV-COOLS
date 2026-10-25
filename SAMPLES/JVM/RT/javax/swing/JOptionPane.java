package javax.swing;
import java.awt.*;
import java.awt.event.*;
public class JOptionPane {
    public static final int YES_NO_OPTION = 0, YES_NO_CANCEL_OPTION = 1, OK_CANCEL_OPTION = 2;
    public static final int YES_OPTION = 0, NO_OPTION = 1, CANCEL_OPTION = 2, OK_OPTION = 0, CLOSED_OPTION = -1;
    public static final int ERROR_MESSAGE = 0, INFORMATION_MESSAGE = 1, WARNING_MESSAGE = 2, QUESTION_MESSAGE = 3, PLAIN_MESSAGE = -1;
    private static int result;
    private static String input;
    private static int dialog(Component parent, String title, Object message, String[] buttons, boolean withInput, String initial) {
        JDialog d = new JDialog((Frame) null, title, true);
        JPanel p = new JPanel(new BorderLayout(10, 10));
        p.setBorder(BorderFactory.createEmptyBorder(12, 16, 10, 16));
        JPanel msg = new JPanel(new GridLayout(0, 1));
        for (String ln : String.valueOf(message).split("\n")) msg.add(new JLabel(ln));
        p.add(msg, BorderLayout.CENTER);
        final JTextField tf = new JTextField(initial == null ? "" : initial, 18);
        if (withInput) { JPanel q = new JPanel(new BorderLayout(0, 6)); q.add(msg, BorderLayout.CENTER); q.add(tf, BorderLayout.SOUTH); p.add(q, BorderLayout.CENTER); }
        JPanel bp = new JPanel(new FlowLayout(FlowLayout.CENTER, 8, 0));
        result = CLOSED_OPTION;
        for (int i = 0; i < buttons.length; i++) {
            final int idx = i;
            JButton b = new JButton(buttons[i]);
            b.addActionListener(e -> { result = idx; input = tf.getText(); d.setVisible(false); });
            bp.add(b);
        }
        p.add(bp, BorderLayout.SOUTH);
        d.getContentPane().add(p);
        d.pack();
        d.setLocationRelativeTo(parent);
        d.setVisible(true);
        return result;
    }
    public static void showMessageDialog(Component parent, Object message) { dialog(parent, "Message", message, new String[] { "OK" }, false, null); }
    public static void showMessageDialog(Component parent, Object message, String title, int type) { dialog(parent, title, message, new String[] { "OK" }, false, null); }
    public static void showMessageDialog(Component parent, Object message, String title, int type, Icon icon) { showMessageDialog(parent, message, title, type); }
    public static int showConfirmDialog(Component parent, Object message) { return showConfirmDialog(parent, message, "Select an Option", YES_NO_CANCEL_OPTION); }
    public static int showConfirmDialog(Component parent, Object message, String title, int optionType) {
        String[] b = optionType == YES_NO_OPTION ? new String[] { "Yes", "No" } : optionType == OK_CANCEL_OPTION ? new String[] { "OK", "Cancel" } : new String[] { "Yes", "No", "Cancel" };
        return dialog(parent, title, message, b, false, null);
    }
    public static int showConfirmDialog(Component parent, Object message, String title, int optionType, int messageType) { return showConfirmDialog(parent, message, title, optionType); }
    public static String showInputDialog(Object message) { return showInputDialog(null, message); }
    public static String showInputDialog(Component parent, Object message) {
        int r = dialog(parent, "Input", message, new String[] { "OK", "Cancel" }, true, null);
        return r == 0 ? input : null;
    }
    public static String showInputDialog(Component parent, Object message, String title, int type) {
        int r = dialog(parent, title, message, new String[] { "OK", "Cancel" }, true, null);
        return r == 0 ? input : null;
    }
    public static String showInputDialog(Object message, Object initial) {
        int r = dialog(null, "Input", message, new String[] { "OK", "Cancel" }, true, String.valueOf(initial));
        return r == 0 ? input : null;
    }
    public static int showOptionDialog(Component parent, Object message, String title, int optionType, int messageType, Icon icon, Object[] options, Object initial) {
        String[] b = new String[options.length];
        for (int i = 0; i < b.length; i++) b[i] = String.valueOf(options[i]);
        return dialog(parent, title, message, b, false, null);
    }
}
