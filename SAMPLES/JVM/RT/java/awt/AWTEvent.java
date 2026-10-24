package java.awt;
public abstract class AWTEvent extends java.util.EventObject {
    protected int id;
    protected boolean consumed = false;
    public AWTEvent(Object source, int id) { super(source); this.id = id; }
    public int getID() { return id; }
    public void consume() { consumed = true; }
    public boolean isConsumed() { return consumed; }
    public String paramString() { return ""; }
    public String toString() { return getClass().getName() + "[" + paramString() + "] on " + source; }
}
