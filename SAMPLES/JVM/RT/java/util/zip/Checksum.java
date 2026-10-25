package java.util.zip;
public interface Checksum {
    void update(int b);
    default void update(byte[] b) { update(b, 0, b.length); }
    void update(byte[] b, int off, int len);
    long getValue();
    void reset();
}
