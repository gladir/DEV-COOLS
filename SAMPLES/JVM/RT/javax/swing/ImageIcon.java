package javax.swing;
import java.awt.*;
public class ImageIcon implements Icon {
    private Image image;
    public ImageIcon() { }
    public ImageIcon(String filename) { }
    public ImageIcon(Image image) { this.image = image; }
    public Image getImage() { return image; }
    public void paintIcon(Component c, Graphics g, int x, int y) { if (image != null) g.drawImage(image, x, y, null); }
    public int getIconWidth() { return image == null ? 0 : image.getWidth(null); }
    public int getIconHeight() { return image == null ? 0 : image.getHeight(null); }
}
