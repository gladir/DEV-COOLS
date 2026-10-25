package java.awt.event;
import java.awt.*;
public class ComponentEvent extends AWTEvent {
    public static final int COMPONENT_MOVED = 100, COMPONENT_RESIZED = 101, COMPONENT_SHOWN = 102, COMPONENT_HIDDEN = 103;
    public ComponentEvent(Component source, int id) { super(source, id); }
    public Component getComponent() { return (source instanceof Component) ? (Component) source : null; }
}
