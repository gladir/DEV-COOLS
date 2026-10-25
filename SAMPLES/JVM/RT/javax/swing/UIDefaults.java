package javax.swing;
public class UIDefaults extends java.util.Hashtable<Object, Object> {
    public interface LazyValue { Object createValue(UIDefaults table); }
    public interface ActiveValue { Object createValue(UIDefaults table); }
    public Object get(Object key) {
        Object v = super.get(key);
        if (v instanceof LazyValue) { v = ((LazyValue) v).createValue(this); super.put(key, v); }
        return v;
    }
}
