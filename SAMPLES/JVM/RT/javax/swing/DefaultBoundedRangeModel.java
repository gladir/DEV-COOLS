package javax.swing;
import javax.swing.event.*;
public class DefaultBoundedRangeModel implements BoundedRangeModel, java.io.Serializable {
    protected transient ChangeEvent changeEvent = null;
    protected EventListenerList listenerList = new EventListenerList();
    private int value = 0;
    private int extent = 0;
    private int min = 0;
    private int max = 100;
    private boolean isAdjusting = false;
    public DefaultBoundedRangeModel() { }
    public DefaultBoundedRangeModel(int value, int extent, int min, int max) {
        if ((max >= min) && (value >= min) && ((value + extent) >= value) && ((value + extent) <= max)) {
            this.value = value; this.extent = extent; this.min = min; this.max = max;
        } else {
            throw new IllegalArgumentException("invalid range properties");
        }
    }
    public int getValue() { return value; }
    public int getExtent() { return extent; }
    public int getMinimum() { return min; }
    public int getMaximum() { return max; }
    public void setValue(int n) {
        n = Math.min(n, Integer.MAX_VALUE - extent);
        int newValue = Math.max(n, min);
        if (newValue + extent > max) newValue = max - extent;
        setRangeProperties(newValue, extent, min, max, isAdjusting);
    }
    public void setExtent(int n) {
        int newExtent = Math.max(0, n);
        if (value + newExtent > max) newExtent = max - value;
        setRangeProperties(value, newExtent, min, max, isAdjusting);
    }
    public void setMinimum(int n) {
        int newMax = Math.max(n, max);
        int newValue = Math.max(n, value);
        int newExtent = Math.min(newMax - newValue, extent);
        setRangeProperties(newValue, newExtent, n, newMax, isAdjusting);
    }
    public void setMaximum(int n) {
        int newMin = Math.min(n, min);
        int newExtent = Math.min(n - newMin, extent);
        int newValue = Math.min(n - newExtent, value);
        setRangeProperties(newValue, newExtent, newMin, n, isAdjusting);
    }
    public void setValueIsAdjusting(boolean b) { setRangeProperties(value, extent, min, max, b); }
    public boolean getValueIsAdjusting() { return isAdjusting; }
    public void setRangeProperties(int newValue, int newExtent, int newMin, int newMax, boolean adjusting) {
        if (newMin > newMax) newMin = newMax;
        if (newValue > newMax) newMax = newValue;
        if (newValue < newMin) newMin = newValue;
        if (((long) newExtent + (long) newValue) > newMax) newExtent = newMax - newValue;
        if (newExtent < 0) newExtent = 0;
        boolean isChanged = (newValue != value) || (newExtent != extent) || (newMin != min) || (newMax != max) || (adjusting != isAdjusting);
        if (isChanged) {
            value = newValue; extent = newExtent; min = newMin; max = newMax; isAdjusting = adjusting;
            fireStateChanged();
        }
    }
    public void addChangeListener(ChangeListener l) { listenerList.add(ChangeListener.class, l); }
    public void removeChangeListener(ChangeListener l) { listenerList.remove(ChangeListener.class, l); }
    public ChangeListener[] getChangeListeners() { return listenerList.getListeners(ChangeListener.class); }
    protected void fireStateChanged() {
        Object[] listeners = listenerList.getListenerList();
        for (int i = listeners.length - 2; i >= 0; i -= 2) {
            if (listeners[i] == ChangeListener.class) {
                if (changeEvent == null) changeEvent = new ChangeEvent(this);
                ((ChangeListener) listeners[i + 1]).stateChanged(changeEvent);
            }
        }
    }
    public String toString() {
        return getClass().getName() + "[value=" + getValue() + ", extent=" + getExtent() + ", min=" + getMinimum() + ", max=" + getMaximum() + ", adj=" + getValueIsAdjusting() + "]";
    }
}
