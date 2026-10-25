package java.awt.event;
import java.awt.*;
public class FocusEvent extends ComponentEvent {
    public static final int FOCUS_FIRST = 1004, FOCUS_GAINED = 1004, FOCUS_LOST = 1005;
    public FocusEvent(Component source, int id) { super(source, id); }
}
