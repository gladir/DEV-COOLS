package java.awt;
public interface Adjustable {
    int HORIZONTAL = 0, VERTICAL = 1, NO_ORIENTATION = 2;
    int getOrientation();
    void setMinimum(int min);
    int getMinimum();
    void setMaximum(int max);
    int getMaximum();
    void setUnitIncrement(int u);
    int getUnitIncrement();
    void setBlockIncrement(int b);
    int getBlockIncrement();
    void setVisibleAmount(int v);
    int getVisibleAmount();
    void setValue(int v);
    int getValue();
    void addAdjustmentListener(java.awt.event.AdjustmentListener l);
    void removeAdjustmentListener(java.awt.event.AdjustmentListener l);
}
