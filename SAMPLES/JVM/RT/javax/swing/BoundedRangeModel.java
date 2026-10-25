package javax.swing;
import javax.swing.event.*;
public interface BoundedRangeModel {
    int getMinimum();
    void setMinimum(int newMinimum);
    int getMaximum();
    void setMaximum(int newMaximum);
    int getValue();
    void setValue(int newValue);
    void setValueIsAdjusting(boolean b);
    boolean getValueIsAdjusting();
    int getExtent();
    void setExtent(int newExtent);
    void setRangeProperties(int value, int extent, int min, int max, boolean adjusting);
    void addChangeListener(ChangeListener x);
    void removeChangeListener(ChangeListener x);
}
