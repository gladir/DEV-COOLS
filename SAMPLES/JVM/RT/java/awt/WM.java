package java.awt;
import java.awt.event.*;
import java.util.ArrayList;
public final class WM {
    private WM() {}
    public static int screenW = 640, screenH = 480;
    static boolean opened, failed;
    static ArrayList<Window> windows = new ArrayList<>();
    static ArrayList<Runnable> queue = new ArrayList<>();
    static ArrayList<Object> timers = new ArrayList<>();
    static Component focusOwner;
    static Component hover, pressTarget;
    static Window dragWin;
    static int dragDx, dragDy;
    static boolean dirty = true;
    static int[] ev = new int[8];
    static int mouseX, mouseY, buttons;
    static int clickCount;
    static long lastClick;
    static int lastClickX, lastClickY;
    static final int DESKTOP = 0x3A6EA5;
    public static boolean ensureOpen() {
        if (opened) return true;
        if (failed) return false;
        if (!Gfx.open(800, 600)) { failed = true; return false; }
        opened = true;
        screenW = Gfx.width();
        screenH = Gfx.height();
        java.lang.VM.pumpHook = new Runnable() { public void run() { pump(); } };
        return true;
    }
    public static void repaint() { dirty = true; }
    public static void invokeLater(Runnable r) { queue.add(r); }
    public static void addTimer(Object t) { if (!timers.contains(t)) timers.add(t); }
    public static void removeTimer(Object t) { timers.remove(t); }
    static void show(Window w) {
        windows.remove(w);
        windows.add(w);
        setActive(w);
        if (focusOwner == null || focusOwner.getWindow() != w) { focusOwner = firstFocusable(w); }
        dirty = true;
    }
    static void hide(Window w) {
        windows.remove(w);
        if (focusOwner != null && focusOwner.getWindow() == w) focusOwner = null;
        if (hover != null && hover.getWindow() == w) hover = null;
        if (pressTarget != null && pressTarget.getWindow() == w) pressTarget = null;
        if (!windows.isEmpty()) { Window top = windows.get(windows.size() - 1); setActive(top); if (focusOwner == null) focusOwner = firstFocusable(top); }
        dirty = true;
    }
    static void raise(Window w) {
        if (windows.remove(w)) { windows.add(w); setActive(w); dirty = true; }
    }
    static void setActive(Window w) {
        for (Window o : windows) if (o != w && o.active) { o.active = false; o.fireWindow(WindowEvent.WINDOW_DEACTIVATED); }
        if (!w.active) { w.active = true; w.fireWindow(WindowEvent.WINDOW_ACTIVATED); }
    }
    static boolean traversable(Component c) { return c.visible && c.enabled && c.focusable && c.focusTraversable(); }
    static void collect(Container c, ArrayList<Component> out) {
        for (int i = 0; i < c.comps.size(); i++) {
            Component k = c.comps.get(i);
            if (!k.visible) continue;
            if (traversable(k)) out.add(k);
            if (k instanceof Container) collect((Container) k, out);
        }
    }
    static Component firstFocusable(Window w) {
        ArrayList<Component> l = new ArrayList<>();
        collect(w, l);
        return l.isEmpty() ? null : l.get(0);
    }
    static void setFocus(Component c) {
        if (focusOwner == c) return;
        Component old = focusOwner;
        focusOwner = c;
        if (old != null) old.dispatchEvent(new FocusEvent(old, FocusEvent.FOCUS_LOST));
        if (c != null) c.dispatchEvent(new FocusEvent(c, FocusEvent.FOCUS_GAINED));
        dirty = true;
    }
    static void nextFocus(Component from, int dir) {
        Window w = from == null ? null : from.getWindow();
        if (w == null && !windows.isEmpty()) w = windows.get(windows.size() - 1);
        if (w == null) return;
        ArrayList<Component> l = new ArrayList<>();
        collect(w, l);
        if (l.isEmpty()) return;
        int i = l.indexOf(from);
        i = i < 0 ? 0 : (i + dir + l.size()) % l.size();
        setFocus(l.get(i));
    }
    static Graphics graphicsFor(Component c) {
        if (!opened) return null;
        Point p = c.getLocationOnScreen();
        Window w = c.getWindow();
        int ox = p.x, oy = p.y;
        ScreenGraphics g = new ScreenGraphics(ox, oy, new Rectangle(ox, oy, c.getWidth(), c.getHeight()));
        return g;
    }
    // ----- evenements -----
    static Window modalTop() {
        for (int i = windows.size() - 1; i >= 0; i--) { Window w = windows.get(i); if (w.modal && w.visible) return w; }
        return null;
    }
    static Window windowAt(int mx, int my) {
        for (int i = windows.size() - 1; i >= 0; i--) {
            Window w = windows.get(i);
            if (w.visible && mx >= w.x && my >= w.y && mx < w.x + w.width && my < w.y + w.height) return w;
        }
        return null;
    }
    static Point originOf(Component c) {
        int ox = 0, oy = 0;
        Component k = c;
        while (k != null) { ox += k.x; oy += k.y; k = k.parent; }
        return new Point(ox, oy);
    }
    static MouseEvent mk(Component c, int id, int mx, int my, int button, int count) {
        Point o = originOf(c);
        int mods = 0;
        if ((buttons & 1) != 0) mods |= InputEvent.BUTTON1_DOWN_MASK;
        return new MouseEvent(c, id, System.currentTimeMillis(), mods, mx - o.x, my - o.y, count, button == 2, button);
    }
    static void deliver(Component target, int id, int mx, int my, int button, int count) {
        Component c = target;
        while (c != null && !c.wantsMouse()) c = c.parent;
        if (c == null) return;
        if (!(c instanceof Window) || true) {
            MouseEvent e = mk(c, id, mx, my, button, count);
            c.dispatchEvent(e);
        }
    }
    static void mouse(int type, int mx, int my, int btn) {
        mouseX = mx; mouseY = my;
        Window modal = modalTop();
        Window w = windowAt(mx, my);
        if (type == 2) {
            buttons |= btn;
            for (int i = windows.size() - 1; i >= 0; i--) { Window pw = windows.get(i); if (pw.popup && pw != w) { pw.setVisible(false); if (w != null) { if (w.popup) { } } } }
            if (w != null && (modal == null || w == modal || w.owner == null)) {
                if (modal == null || w == modal) {
                    raise(w);
                    int lx = mx - w.x, ly = my - w.y;
                    int hit = w.decorationHit(lx, ly);
                    if (hit == 2) { w.closeRequested(); return; }
                    if (hit == 1) { dragWin = w; dragDx = mx - w.x; dragDy = my - w.y; return; }
                    Component t = w.getComponentAt(lx, ly);
                    if (t == null || t == w) t = w;
                    pressTarget = t;
                    Component f = t;
                    while (f != null && !(traversable(f) )) f = f.parent;
                    if (f != null) setFocus(f);
                    long now = System.currentTimeMillis();
                    if (now - lastClick < 400 && Math.abs(mx - lastClickX) < 4 && Math.abs(my - lastClickY) < 4) clickCount++; else clickCount = 1;
                    lastClick = now; lastClickX = mx; lastClickY = my;
                    int b = btn == 1 ? 1 : (btn == 2 ? 3 : 2);
                    t.pressed = false;
                    deliver(t, MouseEvent.MOUSE_PRESSED, mx, my, b, clickCount);
                }
            }
        } else if (type == 3) {
            buttons &= ~btn;
            if (dragWin != null) { dragWin = null; return; }
            int b = btn == 1 ? 1 : (btn == 2 ? 3 : 2);
            Component pt = pressTarget;
            pressTarget = null;
            if (pt != null) {
                deliver(pt, MouseEvent.MOUSE_RELEASED, mx, my, b, clickCount);
                Window pw = pt.getWindow();
                if (pw != null) {
                    Component t = pw.getComponentAt(mx - pw.x, my - pw.y);
                    if (t == pt || (t != null && pt instanceof Container && ((Container) pt).isAncestorOf(t))) deliver(pt, MouseEvent.MOUSE_CLICKED, mx, my, b, clickCount);
                }
            }
        } else if (type == 1) {
            if (dragWin != null) { dragWin.setLocation(mx - dragDx, my - dragDy); dirty = true; return; }
            Component t = null;
            if (w != null && (modal == null || w == modal)) { t = w.getComponentAt(mx - w.x, my - w.y); if (t == null) t = w; }
            if (pressTarget != null) {
                deliver(pressTarget, MouseEvent.MOUSE_DRAGGED, mx, my, 0, 0);
            } else if (t != null) deliver(t, MouseEvent.MOUSE_MOVED, mx, my, 0, 0);
            if (t != hover) {
                Component old = hover;
                hover = t;
                if (old != null) { old.hovered = false; deliver(old, MouseEvent.MOUSE_EXITED, mx, my, 0, 0); }
                if (t != null) { t.hovered = true; deliver(t, MouseEvent.MOUSE_ENTERED, mx, my, 0, 0); }
                dirty = true;
            }
        }
    }
    static void key(int code, int ch) {
        if (windows.isEmpty()) return;
        Window top = windows.get(windows.size() - 1);
        Window modal = modalTop();
        if (modal != null) top = modal;
        int vk = 0;
        char kc = KeyEvent.CHAR_UNDEFINED;
        boolean ctrl = false;
        if (code >= 256) {
            switch (code - 256) {
                case 72: vk = KeyEvent.VK_UP; break; case 80: vk = KeyEvent.VK_DOWN; break; case 75: vk = KeyEvent.VK_LEFT; break; case 77: vk = KeyEvent.VK_RIGHT; break;
                case 71: vk = KeyEvent.VK_HOME; break; case 79: vk = KeyEvent.VK_END; break; case 73: vk = KeyEvent.VK_PAGE_UP; break; case 81: vk = KeyEvent.VK_PAGE_DOWN; break;
                case 83: vk = KeyEvent.VK_DELETE; kc = (char) 127; break; case 82: vk = KeyEvent.VK_INSERT; break;
                default: if (code - 256 >= 59 && code - 256 <= 68) vk = KeyEvent.VK_F1 + (code - 256 - 59);
            }
        } else {
            kc = (char) ch;
            if (ch == 13) { vk = KeyEvent.VK_ENTER; kc = '\n'; }
            else if (ch == 8) vk = KeyEvent.VK_BACK_SPACE;
            else if (ch == 9) vk = KeyEvent.VK_TAB;
            else if (ch == 27) vk = KeyEvent.VK_ESCAPE;
            else if (ch == 32) vk = KeyEvent.VK_SPACE;
            else if (ch >= 'a' && ch <= 'z') vk = ch - 32;
            else if (ch >= 'A' && ch <= 'Z') vk = ch;
            else if (ch >= '0' && ch <= '9') vk = ch;
            else if (ch == ',') vk = KeyEvent.VK_COMMA; else if (ch == '.') vk = KeyEvent.VK_PERIOD; else if (ch == '-') vk = KeyEvent.VK_MINUS; else if (ch == '/') vk = KeyEvent.VK_SLASH;
            else if (ch == '=') vk = KeyEvent.VK_EQUALS; else if (ch == ';') vk = KeyEvent.VK_SEMICOLON;
            else if (ch < 32) { vk = ch + 64; kc = KeyEvent.CHAR_UNDEFINED; ctrl = true; }
        }
        Component target = focusOwner;
        if (target == null || target.getWindow() != top) target = top;
        long now = System.currentTimeMillis();
        int mods = (ch >= 'A' && ch <= 'Z') ? InputEvent.SHIFT_DOWN_MASK : 0;
        if (ctrl) mods |= InputEvent.CTRL_DOWN_MASK;
        boolean tabOwned = false;
        for (Component tc = target; tc != null; tc = tc.parent) if (tc.consumesTab()) { tabOwned = true; break; }
        if (code == 9 && target != top && !tabOwned && !(target instanceof javax.swing.text.JTextComponent && ((javax.swing.text.JTextComponent) target).isMultiLine())) { nextFocus(target, 1); return; }
        KeyEvent pe = new KeyEvent(target, KeyEvent.KEY_PRESSED, now, mods, vk, kc);
        target.dispatchEvent(pe);
        if (!pe.isConsumed() && kc != KeyEvent.CHAR_UNDEFINED && (kc >= 32 || kc == '\n' || kc == '\b' || kc == '\t')) {
            target.dispatchEvent(new KeyEvent(target, KeyEvent.KEY_TYPED, now, mods, KeyEvent.VK_UNDEFINED, kc));
        }
        target.dispatchEvent(new KeyEvent(target, KeyEvent.KEY_RELEASED, now, mods, vk, kc));
        dirty = true;
    }
    // ----- peinture -----
    static void paintAll() {
        if (!opened) return;
        ScreenGraphics.resetClip();
        Gfx.setClip(0, 0, screenW - 1, screenH - 1);
        Gfx.fillRect(0, 0, screenW, screenH, DESKTOP);
        for (int i = 0; i < windows.size(); i++) {
            Window w = windows.get(i);
            if (!w.visible) continue;
            ScreenGraphics g = new ScreenGraphics(w.x, w.y, new Rectangle(w.x, w.y, w.width, w.height));
            w.paint(g);
        }
    }
    static long frame;
    public static int pump() {
        if (!opened) return 0;
        int t, n = 0;
        while ((t = Gfx.poll(ev)) != 0 && n++ < 50) {
            if (t == 4) key(ev[3], ev[4]);
            else if (t == 5) { if (!windows.isEmpty()) windows.get(windows.size() - 1).closeRequested(); }
            else mouse(t, ev[1], ev[2], ev[3]);
        }
        long now = System.currentTimeMillis();
        for (Object o : new ArrayList<>(timers)) ((javax.swing.Timer) o).tick(now);
        while (!queue.isEmpty()) { Runnable r = queue.remove(0); r.run(); }
        if (dirty) { dirty = false; paintAll(); dirty = false; }
        return windows.isEmpty() && queue.isEmpty() ? 0 : 1;
    }
    static void runModal(Window w) {
        while (w.visible) {
            pump();
            Gfx.delay(10);
        }
    }
}
