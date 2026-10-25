package java.awt.event;
import java.awt.*;
public class WindowEvent extends ComponentEvent {
    public static final int WINDOW_FIRST = 200, WINDOW_OPENED = 200, WINDOW_CLOSING = 201, WINDOW_CLOSED = 202, WINDOW_ICONIFIED = 203, WINDOW_DEICONIFIED = 204, WINDOW_ACTIVATED = 205, WINDOW_DEACTIVATED = 206;
    public WindowEvent(Window source, int id) { super(source, id); }
    public Window getWindow() { return (source instanceof Window) ? (Window) source : null; }
}
