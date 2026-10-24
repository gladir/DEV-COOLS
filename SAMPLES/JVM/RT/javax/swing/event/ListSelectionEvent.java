package javax.swing.event;
public class ListSelectionEvent extends java.util.EventObject {
    private int first, last; private boolean adjusting;
    public ListSelectionEvent(Object source, int first, int last, boolean adjusting) { super(source); this.first = first; this.last = last; this.adjusting = adjusting; }
    public int getFirstIndex() { return first; }
    public int getLastIndex() { return last; }
    public boolean getValueIsAdjusting() { return adjusting; }
}
