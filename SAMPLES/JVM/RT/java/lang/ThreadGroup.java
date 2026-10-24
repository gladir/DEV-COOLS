package java.lang;
public class ThreadGroup {
    private final String name;
    public ThreadGroup(String name) { this.name = name; }
    public String getName() { return name; }
    public int activeCount() { return 1; }
}
