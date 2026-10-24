package java.awt;
public class Toolkit {
    private static Toolkit tk = new Toolkit();
    public static Toolkit getDefaultToolkit() { return tk; }
    public Dimension getScreenSize() { WM.ensureOpen(); return new Dimension(WM.screenW, WM.screenH); }
    public void beep() { }
    public void sync() { }
    public int getScreenResolution() { return 96; }
    public Image getImage(String f) { return null; }
    public java.awt.datatransfer.Clipboard getSystemClipboard() { return new java.awt.datatransfer.Clipboard("system"); }
}
