package java.awt.event;
import java.awt.*;
public class MouseWheelEvent extends MouseEvent {
    private int rot;
    public MouseWheelEvent(Component source, int id, long when, int modifiers, int x, int y, int clickCount, boolean popupTrigger, int scrollType, int scrollAmount, int wheelRotation) {
        super(source, id, when, modifiers, x, y, clickCount, popupTrigger); rot = wheelRotation;
    }
    public int getWheelRotation() { return rot; }
}
