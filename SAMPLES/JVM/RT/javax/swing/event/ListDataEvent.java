package javax.swing.event;
public class ListDataEvent extends java.util.EventObject {
    public static final int CONTENTS_CHANGED = 0, INTERVAL_ADDED = 1, INTERVAL_REMOVED = 2;
    private int type, index0, index1;
    public int getType() { return type; }
    public int getIndex0() { return index0; }
    public int getIndex1() { return index1; }
    public ListDataEvent(Object source, int type, int index0, int index1) {
        super(source);
        this.type = type;
        this.index0 = Math.min(index0, index1);
        this.index1 = Math.max(index0, index1);
    }
    public String toString() { return getClass().getName() + "[type=" + type + ",index0=" + index0 + ",index1=" + index1 + "]"; }
}
