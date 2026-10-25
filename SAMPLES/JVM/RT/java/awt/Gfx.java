package java.awt;
public final class Gfx {
    private Gfx() {}
    public static native boolean open(int w, int h);
    public static native void close();
    public static native int width();
    public static native int height();
    public static native void setClip(int x1, int y1, int x2, int y2);
    public static native void fillRect(int x, int y, int w, int h, int rgb);
    public static native void drawLine(int x1, int y1, int x2, int y2, int rgb);
    public static native void drawRect(int x, int y, int w, int h, int rgb);
    public static native void fillOval(int x, int y, int w, int h, int rgb);
    public static native void drawOval(int x, int y, int w, int h, int rgb);
    public static native void arc(int x, int y, int w, int h, int start, int ext, int rgb, int fill);
    public static native void poly(int[] xs, int[] ys, int n, int rgb, int fill);
    public static native void drawText(int x, int y, String s, int rgb, int scale);
    public static native int textWidth(String s, int scale);
    public static native int poll(int[] ev);
    public static native void delay(int ms);
}
