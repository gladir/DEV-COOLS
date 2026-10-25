package java.awt;
public class Cursor implements java.io.Serializable {
    public static final int DEFAULT_CURSOR = 0, CROSSHAIR_CURSOR = 1, TEXT_CURSOR = 2, WAIT_CURSOR = 3, HAND_CURSOR = 12, MOVE_CURSOR = 13;
    private final int type;
    public Cursor(int type) { this.type = type; }
    public int getType() { return type; }
    public static Cursor getDefaultCursor() { return new Cursor(0); }
    public static Cursor getPredefinedCursor(int type) { return new Cursor(type); }
}
