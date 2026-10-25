package java.awt.event;
import java.awt.*;
public abstract class InputEvent extends ComponentEvent {
    public static final int SHIFT_MASK = 1, CTRL_MASK = 2, META_MASK = 4, ALT_MASK = 8;
    public static final int BUTTON1_MASK = 16, BUTTON2_MASK = 8, BUTTON3_MASK = 4;
    public static final int SHIFT_DOWN_MASK = 64, CTRL_DOWN_MASK = 128, META_DOWN_MASK = 256, ALT_DOWN_MASK = 512;
    public static final int BUTTON1_DOWN_MASK = 1024, BUTTON2_DOWN_MASK = 2048, BUTTON3_DOWN_MASK = 4096;
    long when;
    int modifiers;
    InputEvent(Component source, int id, long when, int modifiers) { super(source, id); this.when = when; this.modifiers = modifiers; }
    public long getWhen() { return when; }
    public int getModifiers() { return modifiers; }
    public int getModifiersEx() { return modifiers; }
    public boolean isShiftDown() { return (modifiers & (SHIFT_MASK | SHIFT_DOWN_MASK)) != 0; }
    public boolean isControlDown() { return (modifiers & (CTRL_MASK | CTRL_DOWN_MASK)) != 0; }
    public boolean isAltDown() { return (modifiers & (ALT_MASK | ALT_DOWN_MASK)) != 0; }
    public boolean isMetaDown() { return (modifiers & (META_MASK | META_DOWN_MASK)) != 0; }
}
