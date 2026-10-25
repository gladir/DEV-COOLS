package javax.swing;
import java.awt.event.*;
import java.util.ArrayList;
public class Timer {
    private int delay, initialDelay;
    private boolean repeats = true, running, coalesce = true;
    private long next;
    private final ArrayList<ActionListener> listeners = new ArrayList<>();
    private String command;
    public Timer(int delay, ActionListener listener) { this.delay = delay; this.initialDelay = delay; if (listener != null) listeners.add(listener); }
    public void addActionListener(ActionListener l) { listeners.add(l); }
    public void removeActionListener(ActionListener l) { listeners.remove(l); }
    public void setDelay(int d) { delay = d; }
    public int getDelay() { return delay; }
    public void setInitialDelay(int d) { initialDelay = d; }
    public int getInitialDelay() { return initialDelay; }
    public void setRepeats(boolean r) { repeats = r; }
    public boolean isRepeats() { return repeats; }
    public void setCoalesce(boolean b) { coalesce = b; }
    public void setActionCommand(String c) { command = c; }
    public boolean isRunning() { return running; }
    public void start() { running = true; next = System.currentTimeMillis() + initialDelay; java.awt.WM.addTimer(this); }
    public void restart() { stop(); start(); }
    public void stop() { running = false; java.awt.WM.removeTimer(this); }
    public void tick(long now) {
        if (!running || now < next) return;
        if (repeats) { next = now + Math.max(delay, 1); } else stop();
        ActionEvent e = new ActionEvent(this, ActionEvent.ACTION_PERFORMED, command, now, 0);
        for (ActionListener l : new ArrayList<>(listeners)) l.actionPerformed(e);
        java.awt.WM.repaint();
    }
}
