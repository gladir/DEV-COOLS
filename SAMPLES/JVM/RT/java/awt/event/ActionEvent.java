package java.awt.event;
import java.awt.*;
public class ActionEvent extends AWTEvent {
    public static final int SHIFT_MASK = 1, CTRL_MASK = 2, META_MASK = 4, ALT_MASK = 8;
    public static final int ACTION_FIRST = 1001, ACTION_PERFORMED = 1001;
    String actionCommand;
    long when;
    int modifiers;
    public ActionEvent(Object source, int id, String command) { this(source, id, command, 0); }
    public ActionEvent(Object source, int id, String command, int modifiers) { super(source, id); actionCommand = command; this.modifiers = modifiers; when = System.currentTimeMillis(); }
    public ActionEvent(Object source, int id, String command, long when, int modifiers) { super(source, id); actionCommand = command; this.when = when; this.modifiers = modifiers; }
    public String getActionCommand() { return actionCommand; }
    public long getWhen() { return when; }
    public int getModifiers() { return modifiers; }
    public String paramString() { return "ACTION_PERFORMED,cmd=" + actionCommand + ",when=" + when + ",modifiers=" + modifiers; }
}
