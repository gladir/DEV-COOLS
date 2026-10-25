package java.awt.datatransfer;
public class Clipboard {
    private final String name;
    private Object contents;
    public Clipboard(String name) { this.name = name; }
    public String getName() { return name; }
    public void setContents(Object c, Object owner) { contents = c; }
}
