package java.awt;
public class BasicStroke implements Stroke {
    private final float width;
    public BasicStroke() { this(1.0f); }
    public BasicStroke(float width) { this.width = width; }
    public BasicStroke(float width, int cap, int join) { this.width = width; }
    public float getLineWidth() { return width; }
}
