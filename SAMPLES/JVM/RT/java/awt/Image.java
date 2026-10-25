package java.awt;
public abstract class Image {
    public abstract int getWidth(java.awt.image.ImageObserver observer);
    public abstract int getHeight(java.awt.image.ImageObserver observer);
    public Graphics getGraphics() { return null; }
    public void flush() { }
}
