package javax.swing;
import java.util.ArrayList;
public class ButtonGroup {
    ArrayList<AbstractButton> buttons = new ArrayList<>();
    public void add(AbstractButton b) { buttons.add(b); b.group = this; if (b.isSelected()) select(b); }
    public void remove(AbstractButton b) { buttons.remove(b); b.group = null; }
    void select(AbstractButton b) { for (AbstractButton o : new ArrayList<>(buttons)) if (o != b && o.isSelected()) o.setSelected(false); }
    public int getButtonCount() { return buttons.size(); }
    public void clearSelection() { for (AbstractButton o : buttons) o.setSelected(false); }
    public AbstractButton getSelection() { for (AbstractButton o : buttons) if (o.isSelected()) return o; return null; }
    public java.util.Enumeration<AbstractButton> getElements() { return java.util.Collections.enumeration(buttons); }
}
