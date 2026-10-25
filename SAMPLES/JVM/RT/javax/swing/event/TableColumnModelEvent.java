package javax.swing.event;
import javax.swing.table.TableColumnModel;
public class TableColumnModelEvent extends java.util.EventObject {
    protected int fromIndex, toIndex;
    public TableColumnModelEvent(TableColumnModel source, int from, int to) { super(source); fromIndex = from; toIndex = to; }
    public int getFromIndex() { return fromIndex; }
    public int getToIndex() { return toIndex; }
}
