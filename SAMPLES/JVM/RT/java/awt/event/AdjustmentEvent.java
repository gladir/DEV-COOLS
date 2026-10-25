package java.awt.event;
import java.awt.*;
public class AdjustmentEvent extends AWTEvent {
    public static final int ADJUSTMENT_FIRST = 601, ADJUSTMENT_LAST = 601, ADJUSTMENT_VALUE_CHANGED = 601;
    public static final int UNIT_INCREMENT = 1, UNIT_DECREMENT = 2, BLOCK_DECREMENT = 3, BLOCK_INCREMENT = 4, TRACK = 5;
    Adjustable adjustable;
    int value, adjustmentType;
    boolean isAdjusting;
    public AdjustmentEvent(Adjustable source, int id, int type, int value) { this(source, id, type, value, false); }
    public AdjustmentEvent(Adjustable source, int id, int type, int value, boolean isAdjusting) {
        super(source, id);
        adjustable = source; adjustmentType = type; this.value = value; this.isAdjusting = isAdjusting;
    }
    public Adjustable getAdjustable() { return adjustable; }
    public int getValue() { return value; }
    public int getAdjustmentType() { return adjustmentType; }
    public boolean getValueIsAdjusting() { return isAdjusting; }
    public String paramString() {
        String typeStr;
        switch (adjustmentType) {
            case UNIT_INCREMENT: typeStr = "UNIT_INCREMENT"; break;
            case UNIT_DECREMENT: typeStr = "UNIT_DECREMENT"; break;
            case BLOCK_INCREMENT: typeStr = "BLOCK_INCREMENT"; break;
            case BLOCK_DECREMENT: typeStr = "BLOCK_DECREMENT"; break;
            case TRACK: typeStr = "TRACK"; break;
            default: typeStr = "unknown type";
        }
        return "ADJUSTMENT_VALUE_CHANGED,adjustable=" + adjustable.getClass().getName() + ",value=" + value + ",adjustmentType=" + typeStr + ",isAdjusting=" + isAdjusting;
    }
}
