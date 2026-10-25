package java.beans;
import java.util.*;
public class PropertyChangeSupport implements java.io.Serializable {
    private Object source;
    private transient ArrayList<PropertyChangeListener> all = new ArrayList<>();
    private transient HashMap<String, ArrayList<PropertyChangeListener>> named = new HashMap<>();
    public PropertyChangeSupport(Object sourceBean) {
        if (sourceBean == null) throw new NullPointerException();
        source = sourceBean;
    }
    public void addPropertyChangeListener(PropertyChangeListener listener) {
        if (listener == null) return;
        if (listener instanceof PropertyChangeListenerProxy p) addPropertyChangeListener(p.getPropertyName(), p.getListener());
        else all.add(listener);
    }
    public void removePropertyChangeListener(PropertyChangeListener listener) {
        if (listener == null) return;
        if (listener instanceof PropertyChangeListenerProxy p) removePropertyChangeListener(p.getPropertyName(), p.getListener());
        else all.remove(listener);
    }
    public PropertyChangeListener[] getPropertyChangeListeners() {
        ArrayList<PropertyChangeListener> r = new ArrayList<>(all);
        for (Map.Entry<String, ArrayList<PropertyChangeListener>> e : named.entrySet())
            for (PropertyChangeListener l : e.getValue()) r.add(new PropertyChangeListenerProxy(e.getKey(), l));
        return r.toArray(new PropertyChangeListener[0]);
    }
    public void addPropertyChangeListener(String propertyName, PropertyChangeListener listener) {
        if (listener == null || propertyName == null) return;
        ArrayList<PropertyChangeListener> l = named.get(propertyName);
        if (l == null) { l = new ArrayList<>(); named.put(propertyName, l); }
        l.add(listener);
    }
    public void removePropertyChangeListener(String propertyName, PropertyChangeListener listener) {
        if (listener == null || propertyName == null) return;
        ArrayList<PropertyChangeListener> l = named.get(propertyName);
        if (l != null) { l.remove(listener); if (l.isEmpty()) named.remove(propertyName); }
    }
    public PropertyChangeListener[] getPropertyChangeListeners(String propertyName) {
        ArrayList<PropertyChangeListener> l = propertyName == null ? null : named.get(propertyName);
        return l == null ? new PropertyChangeListener[0] : l.toArray(new PropertyChangeListener[0]);
    }
    public void firePropertyChange(String propertyName, Object oldValue, Object newValue) {
        if (oldValue == null || newValue == null || !oldValue.equals(newValue)) firePropertyChange(new PropertyChangeEvent(source, propertyName, oldValue, newValue));
    }
    public void firePropertyChange(String propertyName, int oldValue, int newValue) {
        if (oldValue != newValue) firePropertyChange(propertyName, Integer.valueOf(oldValue), Integer.valueOf(newValue));
    }
    public void firePropertyChange(String propertyName, boolean oldValue, boolean newValue) {
        if (oldValue != newValue) firePropertyChange(propertyName, Boolean.valueOf(oldValue), Boolean.valueOf(newValue));
    }
    public void firePropertyChange(PropertyChangeEvent event) {
        Object oldValue = event.getOldValue();
        Object newValue = event.getNewValue();
        if (oldValue == null || newValue == null || !oldValue.equals(newValue)) {
            String name = event.getPropertyName();
            for (PropertyChangeListener l : new ArrayList<>(all)) l.propertyChange(event);
            if (name != null) {
                ArrayList<PropertyChangeListener> l = named.get(name);
                if (l != null) for (PropertyChangeListener x : new ArrayList<>(l)) x.propertyChange(event);
            }
        }
    }
    public void fireIndexedPropertyChange(String propertyName, int index, Object oldValue, Object newValue) { firePropertyChange(propertyName, oldValue, newValue); }
    public boolean hasListeners(String propertyName) {
        if (!all.isEmpty()) return true;
        ArrayList<PropertyChangeListener> l = propertyName == null ? null : named.get(propertyName);
        return l != null && !l.isEmpty();
    }
}
