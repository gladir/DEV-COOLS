package java.awt.event;
import java.awt.*;
public class ItemEvent extends AWTEvent {
    public static final int ITEM_STATE_CHANGED = 701, SELECTED = 1, DESELECTED = 2;
    Object item;
    int stateChange;
    public ItemEvent(ItemSelectable source, int id, Object item, int stateChange) { super(source, id); this.item = item; this.stateChange = stateChange; }
    public ItemSelectable getItemSelectable() { return (ItemSelectable) source; }
    public Object getItem() { return item; }
    public int getStateChange() { return stateChange; }
}
