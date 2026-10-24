package java.util.jar;
import java.util.*;
public class Attributes implements Map<Object, Object>, Cloneable {
    protected Map<Object, Object> map;
    public Attributes() { this(11); }
    public Attributes(int size) { map = new LinkedHashMap<>(size); }
    public Attributes(Attributes attr) { map = new LinkedHashMap<>(attr); }
    public Object get(Object name) { return map.get(name); }
    public String getValue(String name) { return (String) get(new Attributes.Name(name)); }
    public String getValue(Attributes.Name name) { return (String) get(name); }
    public Object put(Object name, Object value) { return map.put((Attributes.Name) name, (String) value); }
    public String putValue(String name, String value) { return (String) put(new Name(name), value); }
    public Object remove(Object name) { return map.remove(name); }
    public boolean containsValue(Object value) { return map.containsValue(value); }
    public boolean containsKey(Object name) { return map.containsKey(name); }
    public void putAll(Map<?, ?> attr) {
        if (!Attributes.class.isInstance(attr)) throw new ClassCastException();
        for (Map.Entry<?, ?> me : (attr).entrySet()) put(me.getKey(), me.getValue());
    }
    public void clear() { map.clear(); }
    public int size() { return map.size(); }
    public boolean isEmpty() { return map.isEmpty(); }
    public Set<Object> keySet() { return map.keySet(); }
    public Collection<Object> values() { return map.values(); }
    public Set<Map.Entry<Object, Object>> entrySet() { return map.entrySet(); }
    public boolean equals(Object o) { return map.equals(o); }
    public int hashCode() { return map.hashCode(); }
    public Object clone() { return new Attributes(this); }
    public static class Name {
        private String name;
        private int hashCode = -1;
        public Name(String name) {
            if (name == null) throw new NullPointerException("name");
            if (!isValid(name)) throw new IllegalArgumentException(name);
            this.name = name.intern();
        }
        private static boolean isValid(String name) {
            int len = name.length();
            if (len > 70 || len == 0) return false;
            for (int i = 0; i < len; i++) {
                char c = name.charAt(i);
                if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_')) return false;
            }
            return true;
        }
        public boolean equals(Object o) { return o instanceof Name && name.equalsIgnoreCase(((Name) o).name); }
        public int hashCode() {
            if (hashCode == -1) hashCode = name.toLowerCase(Locale.ROOT).hashCode();
            return hashCode;
        }
        public String toString() { return name; }
        public static final Name MANIFEST_VERSION = new Name("Manifest-Version");
        public static final Name SIGNATURE_VERSION = new Name("Signature-Version");
        public static final Name CONTENT_TYPE = new Name("Content-Type");
        public static final Name CLASS_PATH = new Name("Class-Path");
        public static final Name MAIN_CLASS = new Name("Main-Class");
        public static final Name SEALED = new Name("Sealed");
        public static final Name EXTENSION_LIST = new Name("Extension-List");
        public static final Name EXTENSION_NAME = new Name("Extension-Name");
        public static final Name IMPLEMENTATION_TITLE = new Name("Implementation-Title");
        public static final Name IMPLEMENTATION_VERSION = new Name("Implementation-Version");
        public static final Name IMPLEMENTATION_VENDOR = new Name("Implementation-Vendor");
        public static final Name SPECIFICATION_TITLE = new Name("Specification-Title");
        public static final Name SPECIFICATION_VERSION = new Name("Specification-Version");
        public static final Name SPECIFICATION_VENDOR = new Name("Specification-Vendor");
        public static final Name MULTI_RELEASE = new Name("Multi-Release");
        public static final Name LAUNCHER_AGENT_CLASS = new Name("Launcher-Agent-Class");
    }
}
