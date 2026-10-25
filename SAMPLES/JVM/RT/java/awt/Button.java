package java.awt;
import java.awt.event.*;
public class Button extends Component {
    private String label;
    private String command;
    private java.util.ArrayList<ActionListener> listeners = new java.util.ArrayList<>();
    public Button() { this(""); }
    public Button(String label) { this.label = label; }
    public String getLabel() { return label; }
    public void setLabel(String l) { label = l; invalidate(); WM.repaint(); }
    public void setActionCommand(String c) { command = c; }
    public String getActionCommand() { return command == null ? label : command; }
    public void addActionListener(ActionListener l) { listeners.add(l); }
    public void removeActionListener(ActionListener l) { listeners.remove(l); }
    public boolean wantsMouse() { return true; }
    public boolean focusTraversable() { return true; }
    public Dimension getPreferredSize() { if (prefSize != null) return super.getPreferredSize(); FontMetrics fm = new FontMetrics(getFont()); return new Dimension(fm.stringWidth(label) + 20, fm.getHeight() + 12); }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (!enabled) return;
        if (e.getID() == MouseEvent.MOUSE_PRESSED) { pressed = true; WM.repaint(); }
        else if (e.getID() == MouseEvent.MOUSE_RELEASED) {
            boolean fire = pressed && contains(e.getX(), e.getY());
            pressed = false; WM.repaint();
            if (fire) for (ActionListener l : new java.util.ArrayList<>(listeners)) l.actionPerformed(new ActionEvent(this, ActionEvent.ACTION_PERFORMED, getActionCommand()));
        } else if (e.getID() == MouseEvent.MOUSE_ENTERED || e.getID() == MouseEvent.MOUSE_EXITED) WM.repaint();
    }
    public void paint(Graphics g) {
        Color c = new Color(212, 208, 200);
        g.setColor(pressed ? c.darker() : c);
        g.fillRect(0, 0, width, height);
        g.setColor(Color.BLACK);
        g.drawRect(0, 0, width - 1, height - 1);
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        g.setColor(enabled ? getForeground() : Color.GRAY);
        g.drawString(label, (width - fm.stringWidth(label)) / 2, (height - fm.getHeight()) / 2 + fm.getAscent());
    }
}
