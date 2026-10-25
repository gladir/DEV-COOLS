package java.awt;
import java.awt.event.*;
import java.util.ArrayList;
public abstract class Component implements java.awt.image.ImageObserver, java.io.Serializable {
    public static final float TOP_ALIGNMENT = 0.0f, CENTER_ALIGNMENT = 0.5f, BOTTOM_ALIGNMENT = 1.0f, LEFT_ALIGNMENT = 0.0f, RIGHT_ALIGNMENT = 1.0f;
    public enum BaselineResizeBehavior { CONSTANT_ASCENT, CONSTANT_DESCENT, CENTER_OFFSET, OTHER }
    public BaselineResizeBehavior getBaselineResizeBehavior() { return BaselineResizeBehavior.OTHER; }
    public int getBaseline(int w, int h) { return -1; }
    protected int x, y, width, height;
    protected Container parent;
    protected boolean visible = true, enabled = true, focusable = true, valid = false;
    protected Color background, foreground;
    protected Font font;
    protected String name;
    protected Dimension prefSize, minSize, maxSize;
    ArrayList<MouseListener> mouseListeners;
    ArrayList<MouseMotionListener> motionListeners;
    ArrayList<MouseWheelListener> wheelListeners;
    ArrayList<KeyListener> keyListeners;
    ArrayList<FocusListener> focusListeners;
    ArrayList<ComponentListener> componentListeners;
    protected boolean hovered, pressed;
    protected Component() { }
    public String getName() { return name; }
    public void setName(String n) { name = n; }
    public Container getParent() { return parent; }
    public int getX() { return x; }
    public int getY() { return y; }
    public int getWidth() { return width; }
    public int getHeight() { return height; }
    public Point getLocation() { return new Point(x, y); }
    public Dimension getSize() { return new Dimension(width, height); }
    public Rectangle getBounds() { return new Rectangle(x, y, width, height); }
    public void setLocation(int x, int y) { setBounds(x, y, width, height); }
    public void setLocation(Point p) { setLocation(p.x, p.y); }
    public void setSize(int w, int h) { setBounds(x, y, w, h); }
    public void setSize(Dimension d) { setSize(d.width, d.height); }
    public void setBounds(Rectangle r) { setBounds(r.x, r.y, r.width, r.height); }
    public void setBounds(int x, int y, int w, int h) {
        boolean moved = (this.x != x || this.y != y), resized = (width != w || height != h);
        this.x = x; this.y = y; width = w; height = h;
        if (resized) { valid = false; doLayoutIfNeeded(); }
        if (moved || resized) { WM.repaint(); fireComponent(moved ? ComponentEvent.COMPONENT_MOVED : ComponentEvent.COMPONENT_RESIZED); if (moved && resized) fireComponent(ComponentEvent.COMPONENT_RESIZED); }
    }
    protected void doLayoutIfNeeded() { }
    private void fireComponent(int id) {
        if (componentListeners == null) return;
        ComponentEvent e = new ComponentEvent(this, id);
        for (ComponentListener l : new ArrayList<>(componentListeners)) {
            if (id == ComponentEvent.COMPONENT_MOVED) l.componentMoved(e); else if (id == ComponentEvent.COMPONENT_RESIZED) l.componentResized(e);
            else if (id == ComponentEvent.COMPONENT_SHOWN) l.componentShown(e); else l.componentHidden(e);
        }
    }
    public void setPreferredSize(Dimension d) { prefSize = d; invalidate(); }
    public boolean isPreferredSizeSet() { return prefSize != null; }
    public Dimension getPreferredSize() { return prefSize != null ? new Dimension(prefSize) : new Dimension(width, height); }
    public void setMinimumSize(Dimension d) { minSize = d; }
    public Dimension getMinimumSize() { return minSize != null ? new Dimension(minSize) : getPreferredSize(); }
    public void setMaximumSize(Dimension d) { maxSize = d; }
    public Dimension getMaximumSize() { return maxSize != null ? new Dimension(maxSize) : new Dimension(Integer.MAX_VALUE, Integer.MAX_VALUE); }
    public float getAlignmentX() { return CENTER_ALIGNMENT; }
    public float getAlignmentY() { return CENTER_ALIGNMENT; }
    public boolean isVisible() { return visible; }
    public void setVisible(boolean b) {
        if (visible != b) { visible = b; if (parent != null) parent.invalidate(); WM.repaint(); fireComponent(b ? ComponentEvent.COMPONENT_SHOWN : ComponentEvent.COMPONENT_HIDDEN); }
    }
    public boolean isShowing() { return visible && (parent == null || parent.isShowing()); }
    public boolean isDisplayable() { return true; }
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean b) { if (enabled != b) { enabled = b; WM.repaint(); } }
    public boolean isFocusable() { return focusable; }
    public void setFocusable(boolean b) { focusable = b; }
    public boolean isOpaque() { return true; }
    public boolean isValid() { return valid; }
    public void invalidate() { valid = false; if (parent != null && parent.valid) parent.invalidate(); }
    public void validate() { valid = true; }
    public void revalidate() { invalidate(); Window w = getWindow(); if (w != null) w.validate(); WM.repaint(); }
    public Color getBackground() { return background != null ? background : (parent != null ? parent.getBackground() : defaultBackground()); }
    Color defaultBackground() { return new Color(238, 238, 238); }
    public void setBackground(Color c) { background = c; WM.repaint(); }
    public boolean isBackgroundSet() { return background != null; }
    public Color getForeground() { return foreground != null ? foreground : (parent != null ? parent.getForeground() : Color.BLACK); }
    public void setForeground(Color c) { foreground = c; WM.repaint(); }
    public Font getFont() { return font != null ? font : (parent != null ? parent.getFont() : new Font("Dialog", Font.PLAIN, 12)); }
    public void setFont(Font f) { font = f; invalidate(); WM.repaint(); }
    public boolean isFontSet() { return font != null; }
    public FontMetrics getFontMetrics(Font f) { return new FontMetrics(f); }
    public Cursor getCursor() { return Cursor.getDefaultCursor(); }
    public void setCursor(Cursor c) { }
    public Toolkit getToolkit() { return Toolkit.getDefaultToolkit(); }
    public Graphics getGraphics() { return WM.graphicsFor(this); }
    public void setIgnoreRepaint(boolean b) { }
    public java.awt.image.BufferedImage createImage(int w, int h) { return new java.awt.image.BufferedImage(w, h, 1); }
    public Window getWindow() { Component c = this; while (c != null && !(c instanceof Window)) c = c.parent; return (Window) c; }
    public Point getLocationOnScreen() { int px = 0, py = 0; Component c = this; while (c != null) { px += c.x; py += c.y; c = c.parent; } return new Point(px, py); }
    public Point getLocationInWindow() { return getLocationOnScreen(); }
    public boolean contains(int px, int py) { return px >= 0 && py >= 0 && px < width && py < height; }
    public boolean contains(Point p) { return contains(p.x, p.y); }
    public Component getComponentAt(int px, int py) { return contains(px, py) ? this : null; }
    public Component getComponentAt(Point p) { return getComponentAt(p.x, p.y); }
    public void paint(Graphics g) { }
    public void update(Graphics g) { paint(g); }
    public void paintAll(Graphics g) { paint(g); }
    public void repaint() { WM.repaint(); }
    public void repaint(long tm) { WM.repaint(); }
    public void repaint(int x, int y, int w, int h) { WM.repaint(); }
    public void requestFocus() { if (focusable) WM.setFocus(this); }
    public boolean requestFocusInWindow() { if (focusable) { WM.setFocus(this); return true; } return false; }
    public boolean isFocusOwner() { return WM.focusOwner == this; }
    public void transferFocus() { WM.nextFocus(this, 1); }
    public void setFocusTraversalKeysEnabled(boolean b) { }
    public void addMouseListener(MouseListener l) { if (l == null) return; if (mouseListeners == null) mouseListeners = new ArrayList<>(); mouseListeners.add(l); }
    public void removeMouseListener(MouseListener l) { if (mouseListeners != null) mouseListeners.remove(l); }
    public MouseListener[] getMouseListeners() { return mouseListeners == null ? new MouseListener[0] : mouseListeners.toArray(new MouseListener[0]); }
    public void addMouseMotionListener(MouseMotionListener l) { if (l == null) return; if (motionListeners == null) motionListeners = new ArrayList<>(); motionListeners.add(l); }
    public void removeMouseMotionListener(MouseMotionListener l) { if (motionListeners != null) motionListeners.remove(l); }
    public void addMouseWheelListener(MouseWheelListener l) { if (l == null) return; if (wheelListeners == null) wheelListeners = new ArrayList<>(); wheelListeners.add(l); }
    public void removeMouseWheelListener(MouseWheelListener l) { if (wheelListeners != null) wheelListeners.remove(l); }
    public void addKeyListener(KeyListener l) { if (l == null) return; if (keyListeners == null) keyListeners = new ArrayList<>(); keyListeners.add(l); }
    public void removeKeyListener(KeyListener l) { if (keyListeners != null) keyListeners.remove(l); }
    public KeyListener[] getKeyListeners() { return keyListeners == null ? new KeyListener[0] : keyListeners.toArray(new KeyListener[0]); }
    public void addFocusListener(FocusListener l) { if (l == null) return; if (focusListeners == null) focusListeners = new ArrayList<>(); focusListeners.add(l); }
    public void removeFocusListener(FocusListener l) { if (focusListeners != null) focusListeners.remove(l); }
    public void addComponentListener(ComponentListener l) { if (l == null) return; if (componentListeners == null) componentListeners = new ArrayList<>(); componentListeners.add(l); }
    public void removeComponentListener(ComponentListener l) { if (componentListeners != null) componentListeners.remove(l); }
    public void addKeyBinding(Object o) { }
    public boolean wantsMouse() { return mouseListeners != null || motionListeners != null || wheelListeners != null; }
    public boolean wantsKeys() { return keyListeners != null; }
    public boolean focusTraversable() { return false; }
    public boolean consumesTab() { return false; }
    protected void processMouseEvent(MouseEvent e) {
        if (mouseListeners != null) {
            for (MouseListener l : new ArrayList<>(mouseListeners)) {
                switch (e.getID()) {
                    case MouseEvent.MOUSE_CLICKED: l.mouseClicked(e); break;
                    case MouseEvent.MOUSE_PRESSED: l.mousePressed(e); break;
                    case MouseEvent.MOUSE_RELEASED: l.mouseReleased(e); break;
                    case MouseEvent.MOUSE_ENTERED: l.mouseEntered(e); break;
                    case MouseEvent.MOUSE_EXITED: l.mouseExited(e); break;
                }
            }
        }
    }
    protected void processMouseMotionEvent(MouseEvent e) {
        if (motionListeners != null) {
            for (MouseMotionListener l : new ArrayList<>(motionListeners)) {
                if (e.getID() == MouseEvent.MOUSE_DRAGGED) l.mouseDragged(e); else l.mouseMoved(e);
            }
        }
    }
    protected void processMouseWheelEvent(MouseWheelEvent e) { if (wheelListeners != null) for (MouseWheelListener l : new ArrayList<>(wheelListeners)) l.mouseWheelMoved(e); }
    protected void processKeyEvent(KeyEvent e) {
        if (keyListeners != null) {
            for (KeyListener l : new ArrayList<>(keyListeners)) {
                switch (e.getID()) {
                    case KeyEvent.KEY_TYPED: l.keyTyped(e); break;
                    case KeyEvent.KEY_PRESSED: l.keyPressed(e); break;
                    case KeyEvent.KEY_RELEASED: l.keyReleased(e); break;
                }
            }
        }
    }
    protected void processFocusEvent(FocusEvent e) {
        if (focusListeners != null) for (FocusListener l : new ArrayList<>(focusListeners)) { if (e.getID() == FocusEvent.FOCUS_GAINED) l.focusGained(e); else l.focusLost(e); }
    }
    public void dispatchEvent(AWTEvent e) {
        if (e instanceof MouseWheelEvent) processMouseWheelEvent((MouseWheelEvent) e);
        else if (e instanceof MouseEvent me) { if (me.getID() == MouseEvent.MOUSE_MOVED || me.getID() == MouseEvent.MOUSE_DRAGGED) processMouseMotionEvent(me); else processMouseEvent(me); }
        else if (e instanceof KeyEvent) processKeyEvent((KeyEvent) e);
        else if (e instanceof FocusEvent) processFocusEvent((FocusEvent) e);
    }
    public String toString() { return getClass().getName() + "[" + (name != null ? name + "," : "") + x + "," + y + "," + width + "x" + height + "]"; }
}
