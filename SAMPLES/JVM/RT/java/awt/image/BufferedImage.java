package java.awt.image;
import java.awt.*;
public class BufferedImage extends Image {
    public static final int TYPE_INT_RGB = 1, TYPE_INT_ARGB = 2, TYPE_BYTE_GRAY = 10;
    private final int w, h;
    private final int[] data;
    public BufferedImage(int width, int height, int type) { w = width; h = height; data = new int[width * height]; }
    public int getWidth() { return w; }
    public int getHeight() { return h; }
    public int getWidth(ImageObserver o) { return w; }
    public int getHeight(ImageObserver o) { return h; }
    public int getRGB(int x, int y) { return data[y * w + x]; }
    public void setRGB(int x, int y, int rgb) { if (x >= 0 && y >= 0 && x < w && y < h) data[y * w + x] = rgb; }
    public Graphics getGraphics() { return createGraphics(); }
    public Graphics2D createGraphics() { return new ImageGraphics(this); }
}
