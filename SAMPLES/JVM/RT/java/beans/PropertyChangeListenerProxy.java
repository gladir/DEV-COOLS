package java.beans;
public class PropertyChangeListenerProxy implements PropertyChangeListener {
    private final String propertyName;
    private final PropertyChangeListener listener;
    public PropertyChangeListenerProxy(String propertyName, PropertyChangeListener listener) { this.propertyName = propertyName; this.listener = listener; }
    public void propertyChange(PropertyChangeEvent event) { listener.propertyChange(event); }
    public String getPropertyName() { return propertyName; }
    public PropertyChangeListener getListener() { return listener; }
}
