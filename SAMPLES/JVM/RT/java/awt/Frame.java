package java.awt;
public class Frame extends Window {
    public static final int NORMAL = 0, ICONIFIED = 1, MAXIMIZED_BOTH = 6;
    private boolean resizable = true;
    public Frame() { this(""); }
    public Frame(String title) { super((Window) null); this.title = title; }
    public Frame(GraphicsConfiguration gc) { this(""); }
    public void setResizable(boolean b) { resizable = b; }
    public boolean isResizable() { return resizable; }
    public void setExtendedState(int s) { }
    public int getExtendedState() { return NORMAL; }
    public void setMenuBar(MenuBar mb) { }
    public static Frame[] getFrames() { return new Frame[0]; }
}
