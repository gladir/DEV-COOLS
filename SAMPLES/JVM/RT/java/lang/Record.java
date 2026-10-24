package java.lang;
public abstract class Record {
    protected Record() {}
    public abstract boolean equals(Object obj);
    public abstract int hashCode();
    public abstract String toString();
}
