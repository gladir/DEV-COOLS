package java.awt;
import java.awt.event.*;
import java.util.ArrayList;
public class Window extends Container {
    protected String title = "";
    ArrayList<WindowListener> winListeners = new ArrayList<>();
    protected boolean undecorated, modal, shownOnce, disposed, positioned, popup;
    protected Window owner;
    protected int closeOp = 1;
    protected boolean active;
    static final int TITLE_H = 20, BORDER = 3;
    public Window(Window owner) { this.owner = owner; visible = false; layoutMgr = new BorderLayout(); }
    public Window(Frame owner) { this((Window) owner); }
    public void setTitle(String t) { title = t == null ? "" : t; WM.repaint(); }
    public String getTitle() { return title; }
    public Insets getInsets() { return undecorated ? new Insets(0, 0, 0, 0) : new Insets(BORDER + TITLE_H, BORDER, BORDER, BORDER); }
    public void setUndecorated(boolean b) { undecorated = b; }
    public boolean isUndecorated() { return undecorated; }
    public Window getOwner() { return owner; }
    public void pack() {
        WM.ensureOpen();
        Dimension d = getPreferredSize();
        int minw = undecorated ? 80 : title.length() * 8 + 2 * BORDER + 36;
        setSize(Math.max(d.width, minw), Math.max(d.height, 40));
        validate();
    }
    public void setVisible(boolean b) {
        if (b) {
            if (!WM.ensureOpen()) throw new HeadlessException("No graphics display available (use JVM without -text)");
            if (disposed) disposed = false;
            if (width == 0 || height == 0) pack();
            if (!positioned) { setLocation((WM.screenW - width) / 2 + 8 * WM.windows.size(), (WM.screenH - height) / 2 + 8 * WM.windows.size()); positioned = true; }
            validate();
            if (!visible) {
                visible = true;
                WM.show(this);
                fireWindow(WindowEvent.WINDOW_OPENED);
            } else WM.raise(this);
            if (modal) WM.runModal(this);
        } else if (visible) {
            visible = false;
            WM.hide(this);
        }
    }
    public void show() { setVisible(true); }
    public void hide() { setVisible(false); }
    public void dispose() {
        if (visible) { visible = false; WM.hide(this); }
        if (!disposed) { disposed = true; fireWindow(WindowEvent.WINDOW_CLOSED); }
    }
    public void toFront() { WM.raise(this); }
    public void toBack() { }
    public void setLocationRelativeTo(Component c) {
        WM.ensureOpen();
        if (width == 0 && height == 0) pack();
        if (c == null || !c.isShowing()) setLocation((WM.screenW - width) / 2, (WM.screenH - height) / 2);
        else { Point p = c.getLocationOnScreen(); setLocation(p.x + (c.getWidth() - width) / 2, p.y + (c.getHeight() - height) / 2); }
        positioned = true;
    }
    public void setLocation(int x, int y) { positioned = true; super.setLocation(x, y); }
    public void setBounds(int x, int y, int w, int h) { positioned = true; super.setBounds(x, y, w, h); }
    public boolean isActive() { return active; }
    public boolean isFocused() { return active; }
    public void setAlwaysOnTop(boolean b) { }
    public void setResizable(boolean b) { }
    public void setIconImage(Image i) { }
    public void setModalExclusionType(Object o) { }
    public void addWindowListener(WindowListener l) { if (l != null) winListeners.add(l); }
    public void removeWindowListener(WindowListener l) { winListeners.remove(l); }
    public WindowListener[] getWindowListeners() { return winListeners.toArray(new WindowListener[0]); }
    public void addWindowStateListener(Object l) { }
    public void fireWindow(int id) {
        WindowEvent e = new WindowEvent(this, id);
        for (WindowListener l : new ArrayList<>(winListeners)) {
            switch (id) {
                case WindowEvent.WINDOW_OPENED: l.windowOpened(e); break;
                case WindowEvent.WINDOW_CLOSING: l.windowClosing(e); break;
                case WindowEvent.WINDOW_CLOSED: l.windowClosed(e); break;
                case WindowEvent.WINDOW_ACTIVATED: l.windowActivated(e); break;
                case WindowEvent.WINDOW_DEACTIVATED: l.windowDeactivated(e); break;
                case WindowEvent.WINDOW_ICONIFIED: l.windowIconified(e); break;
                case WindowEvent.WINDOW_DEICONIFIED: l.windowDeiconified(e); break;
            }
        }
    }
    void closeRequested() {
        fireWindow(WindowEvent.WINDOW_CLOSING);
        windowClosingDefault();
    }
    protected void windowClosingDefault() { if (winListeners.isEmpty()) dispose(); }
    Color defaultBackground() { return new Color(238, 238, 238); }
    // 0 aucun, 1 barre de titre, 2 bouton de fermeture
    int decorationHit(int lx, int ly) {
        if (undecorated) return 0;
        if (ly >= BORDER && ly < BORDER + TITLE_H && lx >= BORDER && lx < width - BORDER) {
            if (lx >= width - BORDER - 18) return 2;
            return 1;
        }
        return 0;
    }
    public void paint(Graphics g) {
        if (!undecorated) paintDecoration(g);
        Graphics cg = g.create(0, 0, width, height);
        if (!undecorated) { cg.clipRect(BORDER, BORDER + TITLE_H, width - 2 * BORDER, height - 2 * BORDER - TITLE_H); }
        paintContent(cg);
        cg.dispose();
    }
    protected void paintContent(Graphics g) { g.setColor(getBackground()); g.fillRect(0, 0, width, height); paintChildren(g); }
    void paintDecoration(Graphics g) {
        g.setColor(new Color(212, 208, 200));
        g.fillRect(0, 0, width, height);
        g.setColor(Color.WHITE); g.drawLine(0, 0, width - 1, 0); g.drawLine(0, 0, 0, height - 1);
        g.setColor(new Color(64, 64, 64)); g.drawLine(0, height - 1, width - 1, height - 1); g.drawLine(width - 1, 0, width - 1, height - 1);
        g.setColor(new Color(128, 128, 128)); g.drawLine(1, height - 2, width - 2, height - 2); g.drawLine(width - 2, 1, width - 2, height - 2);
        int tx = BORDER, ty = BORDER, tw = width - 2 * BORDER;
        Color c1 = active ? new Color(10, 36, 106) : new Color(128, 128, 128);
        Color c2 = active ? new Color(166, 202, 240) : new Color(192, 192, 192);
        for (int i = 0; i < tw; i += 4) {
            int r = c1.getRed() + (c2.getRed() - c1.getRed()) * i / tw;
            int gg = c1.getGreen() + (c2.getGreen() - c1.getGreen()) * i / tw;
            int b = c1.getBlue() + (c2.getBlue() - c1.getBlue()) * i / tw;
            g.setColor(new Color(r, gg, b));
            g.fillRect(tx + i, ty, Math.min(4, tw - i), TITLE_H - 3);
        }
        g.setColor(Color.WHITE);
        g.setFont(new Font("Dialog", Font.BOLD, 12));
        String t = title;
        int maxc = (tw - 28) / 8;
        if (t.length() > maxc && maxc > 3) t = t.substring(0, maxc - 2) + "..";
        g.drawString(t, tx + 4, ty + 13);
        int bx = width - BORDER - 17, by = ty + 2;
        g.setColor(new Color(212, 208, 200));
        g.fillRect(bx, by, 16, 13);
        g.setColor(Color.WHITE); g.drawLine(bx, by, bx + 15, by); g.drawLine(bx, by, bx, by + 12);
        g.setColor(new Color(64, 64, 64)); g.drawLine(bx, by + 12, bx + 15, by + 12); g.drawLine(bx + 15, by, bx + 15, by + 12);
        g.setColor(Color.BLACK);
        g.drawLine(bx + 4, by + 3, bx + 11, by + 9); g.drawLine(bx + 5, by + 3, bx + 12, by + 9);
        g.drawLine(bx + 11, by + 3, bx + 4, by + 9); g.drawLine(bx + 12, by + 3, bx + 5, by + 9);
    }
}
