package java.lang;
public class Package {
    private final String name;
    Package(String name) { this.name = name; }
    public String getName() { return name; }
    public String getImplementationVersion() { return null; }
    public String getImplementationTitle() { return null; }
    public String getSpecificationVersion() { return null; }
    public String toString() { return "package " + name; }
    public int hashCode() { return name.hashCode(); }
    public boolean equals(Object o) { return o instanceof Package && ((Package) o).name.equals(name); }
}
