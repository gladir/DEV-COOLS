package java.awt.event;
import java.awt.*;
public class MouseEvent extends InputEvent {
    public static final int MOUSE_FIRST = 500, MOUSE_CLICKED = 500, MOUSE_PRESSED = 501, MOUSE_RELEASED = 502, MOUSE_MOVED = 503, MOUSE_ENTERED = 504, MOUSE_EXITED = 505, MOUSE_DRAGGED = 506, MOUSE_WHEEL = 507;
    public static final int NOBUTTON = 0, BUTTON1 = 1, BUTTON2 = 2, BUTTON3 = 3;
    int x, y, clickCount, button;
    boolean popupTrigger;
    public MouseEvent(Component source, int id, long when, int modifiers, int x, int y, int clickCount, boolean popupTrigger) {
        this(source, id, when, modifiers, x, y, clickCount, popupTrigger, NOBUTTON);
    }
    public MouseEvent(Component source, int id, long when, int modifiers, int x, int y, int clickCount, boolean popupTrigger, int button) {
        super(source, id, when, modifiers);
        this.x = x; this.y = y; this.clickCount = clickCount; this.popupTrigger = popupTrigger; this.button = button;
    }
    public int getX() { return x; }
    public int getY() { return y; }
    public Point getPoint() { return new Point(x, y); }
    public int getClickCount() { return clickCount; }
    public int getButton() { return button; }
    public boolean isPopupTrigger() { return popupTrigger; }
    public void translatePoint(int dx, int dy) { x += dx; y += dy; }
    public String paramString() {
        String s = id == MOUSE_CLICKED ? "MOUSE_CLICKED" : id == MOUSE_PRESSED ? "MOUSE_PRESSED" : id == MOUSE_RELEASED ? "MOUSE_RELEASED" : id == MOUSE_MOVED ? "MOUSE_MOVED" : id == MOUSE_ENTERED ? "MOUSE_ENTERED" : id == MOUSE_EXITED ? "MOUSE_EXITED" : "MOUSE_DRAGGED";
        return s + ",(" + x + "," + y + "),button=" + button + ",clickCount=" + clickCount;
    }
}
