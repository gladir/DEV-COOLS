package javax.swing;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import javax.swing.event.*;
public class JTabbedPane extends JComponent implements SwingConstants {
    public static final int WRAP_TAB_LAYOUT = 0, SCROLL_TAB_LAYOUT = 1;
    static class Page {
        String title; Icon icon, disabledIcon; Component comp; String tip; boolean enabled = true; Color fg, bg; int mnemonic = -1; Component tabComp;
    }
    protected SingleSelectionModel model;
    protected int tabPlacement = TOP;
    private int tabLayoutPolicy = WRAP_TAB_LAYOUT;
    private final ArrayList<Page> pages = new ArrayList<>();
    private final ArrayList<ChangeListener> changeListeners = new ArrayList<>();
    private Rectangle[] rects = new Rectangle[0];
    private Rectangle contentRect = new Rectangle();
    private int areaSize;
    private boolean tabsValid;
    private int leading;
    private boolean ensureSel;
    private Rectangle tabClip;
    private Rectangle[] scrollBtn;
    private int scrollOff, scrollMax;
    static final int SBTN = 16;
    private ChangeListener modelListener = new ChangeListener() {
        public void stateChanged(ChangeEvent e) { fireStateChanged(); ensureSel = true; tabsValid = false; revalidate(); repaint(); }
    };
    public JTabbedPane() { this(TOP, WRAP_TAB_LAYOUT); }
    public JTabbedPane(int tabPlacement) { this(tabPlacement, WRAP_TAB_LAYOUT); }
    public JTabbedPane(int tabPlacement, int tabLayoutPolicy) {
        setTabPlacement(tabPlacement);
        setTabLayoutPolicy(tabLayoutPolicy);
        opaque = true;
        setModel(new DefaultSingleSelectionModel());
    }
    public SingleSelectionModel getModel() { return model; }
    public void setModel(SingleSelectionModel m) {
        SingleSelectionModel old = getModel();
        if (old != null) old.removeChangeListener(modelListener);
        model = m;
        if (m != null) m.addChangeListener(modelListener);
        firePropertyChange("model", old, m);
        tabsValid = false;
        repaint();
    }
    public int getTabPlacement() { return tabPlacement; }
    public void setTabPlacement(int p) {
        if (p != TOP && p != LEFT && p != BOTTOM && p != RIGHT) throw new IllegalArgumentException("illegal tab placement: must be TOP, BOTTOM, LEFT, or RIGHT");
        if (tabPlacement != p) {
            int old = tabPlacement;
            tabPlacement = p;
            firePropertyChange("tabPlacement", old, p);
            tabsValid = false;
            revalidate(); repaint();
        }
    }
    public int getTabLayoutPolicy() { return tabLayoutPolicy; }
    public void setTabLayoutPolicy(int p) {
        if (p != WRAP_TAB_LAYOUT && p != SCROLL_TAB_LAYOUT) throw new IllegalArgumentException("illegal tab layout policy: must be WRAP_TAB_LAYOUT or SCROLL_TAB_LAYOUT");
        if (tabLayoutPolicy != p) { int old = tabLayoutPolicy; tabLayoutPolicy = p; firePropertyChange("tabLayoutPolicy", old, p); tabsValid = false; revalidate(); repaint(); }
    }
    public int getSelectedIndex() { return model.getSelectedIndex(); }
    public void setSelectedIndex(int index) {
        if (index != -1) checkIndex(index);
        int old = model.getSelectedIndex();
        if (old != index) { model.setSelectedIndex(index); }
    }
    public Component getSelectedComponent() { int i = getSelectedIndex(); return i < 0 ? null : getComponentAt(i); }
    public void setSelectedComponent(Component c) {
        int i = indexOfComponent(c);
        if (i != -1) setSelectedIndex(i);
        else throw new IllegalArgumentException("component not found in tabbed pane");
    }
    public void addChangeListener(ChangeListener l) { changeListeners.add(l); }
    public void removeChangeListener(ChangeListener l) { changeListeners.remove(l); }
    public ChangeListener[] getChangeListeners() { return changeListeners.toArray(new ChangeListener[0]); }
    protected void fireStateChanged() {
        ChangeEvent e = new ChangeEvent(this);
        for (int i = changeListeners.size() - 1; i >= 0; i--) changeListeners.get(i).stateChanged(e);
    }
    private void checkIndex(int index) {
        if (index < 0 || index >= pages.size()) throw new IndexOutOfBoundsException("Index: " + index + ", Tab count: " + pages.size());
    }
    public void insertTab(String title, Icon icon, Component component, String tip, int index) {
        int newIndex = index;
        int removeIndex = indexOfComponent(component);
        if (component != null && removeIndex != -1) { removeTabAt(removeIndex); if (newIndex > removeIndex) newIndex--; }
        int selected = getSelectedIndex();
        Page p = new Page();
        p.title = title; p.icon = icon; p.comp = component; p.tip = tip;
        if (newIndex < 0 || newIndex > pages.size()) newIndex = pages.size();
        pages.add(newIndex, p);
        if (component != null) {
            addImpl(component, null, -1);
            component.setVisible(false);
        }
        if (pages.size() == 1) setSelectedIndex(0);
        else if (selected >= newIndex && selected >= 0) model.setSelectedIndex(selected + 1);
        tabsValid = false;
        revalidate(); repaint();
    }
    public void addTab(String title, Icon icon, Component component, String tip) { insertTab(title, icon, component, tip, pages.size()); }
    public void addTab(String title, Icon icon, Component component) { insertTab(title, icon, component, null, pages.size()); }
    public void addTab(String title, Component component) { insertTab(title, null, component, null, pages.size()); }
    public Component add(Component component) {
        addTab(component.getName(), component);
        return component;
    }
    public Component add(String title, Component component) { addTab(title, component); return component; }
    public Component add(Component component, int index) { insertTab(component.getName(), null, component, null, index == -1 ? pages.size() : index); return component; }
    public void add(Component component, Object constraints) {
        if (constraints instanceof String) addTab((String) constraints, component);
        else if (constraints instanceof Icon) addTab(null, (Icon) constraints, component);
        else add(component);
    }
    public void add(Component component, Object constraints, int index) {
        Icon icon = constraints instanceof Icon ? (Icon) constraints : null;
        String title = constraints instanceof String ? (String) constraints : null;
        insertTab(title, icon, component, null, index == -1 ? pages.size() : index);
    }
    public void removeTabAt(int index) {
        checkIndex(index);
        int sel = getSelectedIndex();
        Component c = pages.get(index).comp;
        pages.remove(index);
        if (c != null) super.remove(c);
        tabsValid = false;
        if (pages.isEmpty()) model.setSelectedIndex(-1);
        else if (sel == index) {
            int ni = Math.min(index, pages.size() - 1);
            if (ni != sel) model.setSelectedIndex(ni); else modelListener.stateChanged(null);
        } else if (sel > index) model.setSelectedIndex(sel - 1);
        revalidate(); repaint();
    }
    public void remove(Component component) {
        int index = indexOfComponent(component);
        if (index != -1) removeTabAt(index); else super.remove(component);
    }
    public void remove(int index) {
        Component c = getComponent(index);
        int tab = indexOfComponent(c);
        if (tab >= 0) removeTabAt(tab); else super.remove(index);
    }
    public void removeAll() {
        model.setSelectedIndex(-1);
        pages.clear();
        super.removeAll();
        tabsValid = false;
        revalidate(); repaint();
    }
    public int getTabCount() { return pages.size(); }
    public int getTabRunCount() { computeTabs(); return runCount; }
    public String getTitleAt(int i) { return pages.get(i).title; }
    public Icon getIconAt(int i) { return pages.get(i).icon; }
    public Icon getDisabledIconAt(int i) { Page p = pages.get(i); return p.disabledIcon; }
    public String getToolTipTextAt(int i) { return pages.get(i).tip; }
    public Color getBackgroundAt(int i) { Page p = pages.get(i); return p.bg != null ? p.bg : getBackground(); }
    public Color getForegroundAt(int i) { Page p = pages.get(i); return p.fg != null ? p.fg : getForeground(); }
    public boolean isEnabledAt(int i) { return pages.get(i).enabled; }
    public Component getComponentAt(int i) { return pages.get(i).comp; }
    public int getMnemonicAt(int i) { return pages.get(i).mnemonic; }
    public Component getTabComponentAt(int i) { return pages.get(i).tabComp; }
    public void setTitleAt(int i, String t) { String old = pages.get(i).title; pages.get(i).title = t; tabsValid = false; firePropertyChange("indexForTitle", -1, i); revalidate(); repaint(); }
    public void setIconAt(int i, Icon ic) { pages.get(i).icon = ic; tabsValid = false; revalidate(); repaint(); }
    public void setDisabledIconAt(int i, Icon ic) { pages.get(i).disabledIcon = ic; repaint(); }
    public void setToolTipTextAt(int i, String t) { pages.get(i).tip = t; }
    public void setBackgroundAt(int i, Color c) { pages.get(i).bg = c; repaint(); }
    public void setForegroundAt(int i, Color c) { pages.get(i).fg = c; repaint(); }
    public void setEnabledAt(int i, boolean b) { pages.get(i).enabled = b; repaint(); }
    public void setMnemonicAt(int i, int m) { pages.get(i).mnemonic = m; }
    public void setDisplayedMnemonicIndexAt(int i, int m) { }
    public void setTabComponentAt(int i, Component c) { pages.get(i).tabComp = c; }
    public void setComponentAt(int i, Component c) {
        checkIndex(i);
        Page p = pages.get(i);
        if (c != p.comp) {
            if (p.comp != null) super.remove(p.comp);
            p.comp = c;
            if (c != null) { addImpl(c, null, -1); c.setVisible(i == getSelectedIndex()); }
            revalidate(); repaint();
        }
    }
    public int indexOfTab(String title) {
        for (int i = 0; i < pages.size(); i++) if (Objects.equals(title, pages.get(i).title)) return i;
        return -1;
    }
    public int indexOfTab(Icon icon) {
        for (int i = 0; i < pages.size(); i++) if (Objects.equals(icon, pages.get(i).icon)) return i;
        return -1;
    }
    public int indexOfComponent(Component c) {
        for (int i = 0; i < pages.size(); i++) if (pages.get(i).comp == c) return i;
        return -1;
    }
    public int indexOfTabComponent(Component c) {
        for (int i = 0; i < pages.size(); i++) if (pages.get(i).tabComp == c) return i;
        return -1;
    }
    public Rectangle getBoundsAt(int i) { checkIndex(i); computeTabs(); return new Rectangle(rects[i]); }
    public int tabForCoordinate(int x, int y) { return indexAtLocation(x, y); }
    public int indexAtLocation(int x, int y) {
        computeTabs();
        if (tabClip != null && !tabClip.contains(x, y)) return -1;
        for (int i = 0; i < rects.length; i++) if (rects[i].contains(x, y)) return i;
        return -1;
    }
    public String getToolTipText(MouseEvent e) { int i = indexAtLocation(e.getX(), e.getY()); return i >= 0 ? getToolTipTextAt(i) : null; }
    // ---- mise en page ----
    private int runCount = 1;
    private int tabH() {
        FontMetrics fm = new FontMetrics(getFont());
        int h = fm.getHeight() + 9;
        for (Page p : pages) if (p.icon != null) h = Math.max(h, p.icon.getIconHeight() + 9);
        return h;
    }
    private int tabW(Page p, FontMetrics fm) {
        String t = p.title == null ? "" : p.title;
        int w = fm.stringWidth(t) + 14;
        if (p.icon != null) w += p.icon.getIconWidth() + (t.isEmpty() ? 0 : 4);
        return Math.max(w, 24);
    }
    void computeTabs() {
        if (tabsValid && rects.length == pages.size()) return;
        int n = pages.size();
        rects = new Rectangle[n];
        FontMetrics fm = new FontMetrics(getFont());
        int th = tabH();
        int[] tw = new int[n];
        for (int i = 0; i < n; i++) tw[i] = tabW(pages.get(i), fm);
        int sel = getSelectedIndex();
        tabClip = null;
        scrollBtn = null;
        if (tabLayoutPolicy == SCROLL_TAB_LAYOUT && n > 0) {
            boolean horiz = tabPlacement == TOP || tabPlacement == BOTTOM;
            int[] start = new int[n + 1];
            int[] len = new int[n];
            int mw = 0;
            for (int i = 0; i < n; i++) mw = Math.max(mw, tw[i]);
            for (int i = 0; i < n; i++) { len[i] = horiz ? tw[i] : th; start[i + 1] = start[i] + len[i]; }
            int total = start[n];
            int avail = horiz ? (width > 0 ? width : 100000) : (height > 0 ? height : 100000);
            boolean need = total > avail;
            int vis = need ? avail - (horiz ? 2 * SBTN : SBTN) : avail;
            if (vis < 1) vis = 1;
            scrollMax = Math.max(0, total - vis);
            if (leading >= n) leading = n - 1;
            if (leading < 0) leading = 0;
            if (ensureSel && sel >= 0 && sel < n) {
                ensureSel = false;
                int off = Math.min(start[leading], scrollMax);
                if (start[sel] < off) leading = sel;
                else if (start[sel + 1] > off + vis) {
                    int l = leading;
                    while (l < sel && start[sel + 1] - start[l] > vis) l++;
                    leading = l;
                }
            }
            scrollOff = need ? Math.min(start[leading], scrollMax) : 0;
            int cross = horiz ? th : mw;
            for (int i = 0; i < n; i++) {
                int pos = start[i] - scrollOff;
                if (horiz) rects[i] = new Rectangle(pos, tabPlacement == TOP ? 0 : height - th, tw[i], th);
                else rects[i] = new Rectangle(tabPlacement == LEFT ? 0 : width - mw, pos, mw, th);
            }
            runCount = 1;
            areaSize = cross;
            if (horiz) {
                int y = tabPlacement == TOP ? 0 : height - th;
                tabClip = new Rectangle(0, y, vis, th);
                if (need) scrollBtn = new Rectangle[] { new Rectangle(vis, y, SBTN, th), new Rectangle(vis + SBTN, y, SBTN, th) };
                if (tabPlacement == TOP) contentRect = new Rectangle(0, areaSize - 1, width, Math.max(0, height - areaSize + 1));
                else contentRect = new Rectangle(0, 0, width, Math.max(0, height - areaSize + 1));
            } else {
                int x = tabPlacement == LEFT ? 0 : width - mw;
                tabClip = new Rectangle(x, 0, mw, vis);
                if (need) scrollBtn = new Rectangle[] { new Rectangle(x, vis, mw / 2, SBTN), new Rectangle(x + mw / 2, vis, mw - mw / 2, SBTN) };
                if (tabPlacement == LEFT) contentRect = new Rectangle(areaSize - 1, 0, Math.max(0, width - areaSize + 1), height);
                else contentRect = new Rectangle(0, 0, Math.max(0, width - areaSize + 1), height);
            }
            tabsValid = true;
            return;
        }
        if (tabPlacement == TOP || tabPlacement == BOTTOM) {
            int avail = width > 0 ? width : 100000;
            ArrayList<int[]> runs = new ArrayList<>();
            int start = 0, cur = 0;
            for (int i = 0; i < n; i++) {
                if (cur > 0 && cur + tw[i] > avail) { runs.add(new int[] { start, i - 1 }); start = i; cur = 0; }
                cur += tw[i];
            }
            if (n > 0) runs.add(new int[] { start, n - 1 });
            runCount = Math.max(1, runs.size());
            int selRun = 0;
            for (int r = 0; r < runs.size(); r++) if (sel >= runs.get(r)[0] && sel <= runs.get(r)[1]) selRun = r;
            for (int r = 0; r < runs.size(); r++) {
                int[] run = runs.get(r);
                int pos = tabPlacement == TOP ? (r + runCount - 1 - selRun) % runCount : (r - selRun + runCount) % runCount;
                int cnt = run[1] - run[0] + 1;
                int sum = 0;
                for (int i = run[0]; i <= run[1]; i++) sum += tw[i];
                int extra = runCount > 1 ? avail - sum : 0;
                int x = 0;
                int y = tabPlacement == TOP ? pos * th : height - (runCount - pos) * th;
                for (int i = run[0]; i <= run[1]; i++) {
                    int w = tw[i];
                    if (extra > 0) { int add = extra / cnt; if (i == run[1]) add = extra - (extra / cnt) * (cnt - 1); w += add; }
                    rects[i] = new Rectangle(x, y, w, th);
                    x += w;
                }
            }
            areaSize = runCount * th;
            if (tabPlacement == TOP) contentRect = new Rectangle(0, areaSize - 1, width, Math.max(0, height - areaSize + 1));
            else contentRect = new Rectangle(0, 0, width, Math.max(0, height - areaSize + 1));
        } else {
            runCount = 1;
            int mw = 0;
            for (int i = 0; i < n; i++) mw = Math.max(mw, tw[i]);
            for (int i = 0; i < n; i++) rects[i] = new Rectangle(tabPlacement == LEFT ? 0 : width - mw, i * th, mw, th);
            areaSize = mw;
            if (tabPlacement == LEFT) contentRect = new Rectangle(areaSize - 1, 0, Math.max(0, width - areaSize + 1), height);
            else contentRect = new Rectangle(0, 0, Math.max(0, width - areaSize + 1), height);
        }
        tabsValid = true;
    }
    public void doLayout() {
        tabsValid = false;
        computeTabs();
        int sel = getSelectedIndex();
        for (int i = 0; i < pages.size(); i++) {
            Component c = pages.get(i).comp;
            if (c == null) continue;
            if (i == sel) {
                c.setVisible(true);
                c.setBounds(contentRect.x + 2, contentRect.y + 2, Math.max(0, contentRect.width - 4), Math.max(0, contentRect.height - 4));
            } else c.setVisible(false);
        }
    }
    public void setBounds(int x, int y, int w, int h) { tabsValid = false; super.setBounds(x, y, w, h); }
    public Dimension getPreferredSize() {
        if (prefSize != null) return new Dimension(prefSize);
        FontMetrics fm = new FontMetrics(getFont());
        int th = tabH();
        int cw = 0, ch = 0, total = 0, mw = 0;
        for (Page p : pages) {
            if (p.comp != null) { Dimension d = p.comp.getPreferredSize(); cw = Math.max(cw, d.width); ch = Math.max(ch, d.height); }
            int w = tabW(p, fm);
            total += w; mw = Math.max(mw, w);
        }
        Insets in = getInsets();
        if (tabPlacement == TOP || tabPlacement == BOTTOM)
            return new Dimension(Math.max(cw + 4, total) + in.left + in.right, ch + 4 + th - 1 + in.top + in.bottom);
        return new Dimension(cw + 4 + mw - 1 + in.left + in.right, Math.max(ch + 4, th * pages.size()) + in.top + in.bottom);
    }
    public Dimension getMinimumSize() {
        if (minSize != null) return new Dimension(minSize);
        int cw = 0, ch = 0;
        for (Page p : pages) if (p.comp != null) { Dimension d = p.comp.getMinimumSize(); cw = Math.max(cw, d.width); ch = Math.max(ch, d.height); }
        Dimension pr = getPreferredSize();
        return new Dimension(Math.min(pr.width, cw + 30), Math.min(pr.height, ch + 4 + tabH()));
    }
    // ---- evenements ----
    public boolean wantsMouse() { return true; }
    public boolean focusTraversable() { return true; }
    public boolean wantsKeys() { return true; }
    protected void processMouseEvent(MouseEvent e) {
        super.processMouseEvent(e);
        if (e.getID() == MouseEvent.MOUSE_PRESSED && e.getButton() == 1 && enabled) {
            computeTabs();
            if (scrollBtn != null) {
                for (int b = 0; b < 2; b++) {
                    if (scrollBtn[b].contains(e.getX(), e.getY())) {
                        if (b == 0 && scrollOff > 0) leading--;
                        else if (b == 1 && scrollOff < scrollMax) leading++;
                        tabsValid = false;
                        repaint();
                        return;
                    }
                }
            }
            int i = indexAtLocation(e.getX(), e.getY());
            if (i >= 0 && pages.get(i).enabled) {
                if (i != getSelectedIndex()) setSelectedIndex(i);
                requestFocus();
            }
        }
    }
    private void navigate(int dir) {
        int n = pages.size(), sel = getSelectedIndex();
        if (n == 0) return;
        for (int k = 1; k <= n; k++) {
            int i = ((sel + dir * k) % n + n) % n;
            if (pages.get(i).enabled) { setSelectedIndex(i); return; }
        }
    }
    protected void processKeyEvent(KeyEvent e) {
        super.processKeyEvent(e);
        if (e.isConsumed() || e.getID() != KeyEvent.KEY_PRESSED || !enabled) return;
        switch (e.getKeyCode()) {
            case KeyEvent.VK_LEFT: case KeyEvent.VK_UP: navigate(-1); e.consume(); break;
            case KeyEvent.VK_RIGHT: case KeyEvent.VK_DOWN: navigate(1); e.consume(); break;
            case KeyEvent.VK_HOME: if (!pages.isEmpty()) setSelectedIndex(0); e.consume(); break;
            case KeyEvent.VK_END: if (!pages.isEmpty()) setSelectedIndex(pages.size() - 1); e.consume(); break;
        }
    }
    // ---- peinture ----
    protected void paintComponent(Graphics g) {
        g.setColor(getBackground());
        g.fillRect(0, 0, width, height);
        computeTabs();
        Color line = new Color(122, 138, 153);
        int sel = getSelectedIndex();
        Rectangle c = contentRect;
        g.setColor(line);
        g.drawRect(c.x, c.y, Math.max(0, c.width - 1), Math.max(0, c.height - 1));
        // fond clair en haut du contenu
        g.setColor(Color.WHITE);
        if (tabPlacement == TOP) g.drawLine(c.x + 1, c.y + 1, c.x + c.width - 3, c.y + 1);
        FontMetrics fm = g.getFontMetrics(getFont());
        g.setFont(getFont());
        Graphics tg = g;
        if (tabClip != null) {
            tg = g.create(tabClip.x, tabClip.y, tabClip.width, tabClip.height);
            tg.translate(-tabClip.x, -tabClip.y);
            tg.setFont(getFont());
        }
        for (int pass = 0; pass < 2; pass++) {
            for (int i = 0; i < rects.length; i++) {
                if ((i == sel) != (pass == 1)) continue;
                paintTab(tg, i, rects[i], i == sel, line, fm);
            }
        }
        if (tabClip != null) tg.dispose();
        if (scrollBtn != null) {
            boolean horiz = tabPlacement == TOP || tabPlacement == BOTTOM;
            for (int b = 0; b < 2; b++) {
                Rectangle r = scrollBtn[b];
                boolean on = b == 0 ? scrollOff > 0 : scrollOff < scrollMax;
                if (on) AbstractButton.gradient(g, r.x + 1, r.y + 1, r.width - 2, r.height - 2, false, false);
                else { g.setColor(new Color(238, 238, 238)); g.fillRect(r.x + 1, r.y + 1, r.width - 2, r.height - 2); }
                g.setColor(on ? line : new Color(184, 184, 184));
                g.drawRect(r.x, r.y, r.width - 1, r.height - 1);
                g.setColor(on ? new Color(51, 51, 51) : new Color(153, 153, 153));
                JScrollBar.arrow(g, r.x + r.width / 2, r.y + r.height / 2, horiz ? 2 + b : b);
            }
        }
    }
    private void paintTab(Graphics g, int i, Rectangle r, boolean selected, Color line, FontMetrics fm) {
        Page p = pages.get(i);
        Color bg = selected ? new Color(238, 238, 238) : (p.bg != null ? p.bg : new Color(214, 223, 232));
        g.setColor(bg);
        g.fillRect(r.x, r.y, r.width, r.height);
        if (!selected) { g.setColor(new Color(226, 232, 238)); }
        g.setColor(line);
        int x0 = r.x, y0 = r.y, x1 = r.x + r.width - 1, y1 = r.y + r.height - 1;
        switch (tabPlacement) {
            case TOP:
                g.drawLine(x0, y0 + 1, x0, y1); g.drawLine(x0 + 1, y0, x1 - 1, y0); g.drawLine(x1, y0 + 1, x1, y1);
                if (selected) { g.setColor(bg); g.drawLine(x0 + 1, y1, x1 - 1, y1); }
                break;
            case BOTTOM:
                g.drawLine(x0, y0, x0, y1 - 1); g.drawLine(x0 + 1, y1, x1 - 1, y1); g.drawLine(x1, y0, x1, y1 - 1);
                if (selected) { g.setColor(bg); g.drawLine(x0 + 1, y0, x1 - 1, y0); }
                break;
            case LEFT:
                g.drawLine(x0 + 1, y0, x1, y0); g.drawLine(x0, y0 + 1, x0, y1 - 1); g.drawLine(x0 + 1, y1, x1, y1);
                if (selected) { g.setColor(bg); g.drawLine(x1, y0 + 1, x1, y1 - 1); }
                break;
            default:
                g.drawLine(x0, y0, x1 - 1, y0); g.drawLine(x1, y0 + 1, x1, y1 - 1); g.drawLine(x0, y1, x1 - 1, y1);
                if (selected) { g.setColor(bg); g.drawLine(x0, y0 + 1, x0, y1 - 1); }
                break;
        }
        if (selected && tabPlacement == TOP) { g.setColor(Color.WHITE); g.drawLine(x0 + 1, y0 + 1, x1 - 1, y0 + 1); }
        String t = p.title == null ? "" : p.title;
        int tw = fm.stringWidth(t);
        int iw = p.icon != null ? p.icon.getIconWidth() + (t.isEmpty() ? 0 : 4) : 0;
        int x = r.x + (r.width - tw - iw) / 2;
        int th = Math.max(fm.getHeight(), p.icon != null ? p.icon.getIconHeight() : 0);
        int y = r.y + (r.height - th) / 2;
        if (p.icon != null) { p.icon.paintIcon(this, g, x, y + (th - p.icon.getIconHeight()) / 2); x += iw; }
        Color fg = !p.enabled || !enabled ? new Color(153, 153, 153) : (p.fg != null ? p.fg : new Color(51, 51, 51));
        g.setColor(fg);
        g.drawString(t, x, y + (th - fm.getHeight()) / 2 + fm.getAscent());
        if (selected && isFocusOwner()) {
            g.setColor(new Color(99, 130, 191));
            g.drawRect(r.x + 3, r.y + 3, r.width - 7, r.height - 7);
        }
    }
}
