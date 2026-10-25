package java.io;
public interface ObjectOutput extends DataOutput, AutoCloseable {
    void writeObject(Object obj) throws IOException;
    void write(int b) throws IOException;
    void write(byte[] b) throws IOException;
    void write(byte[] b, int off, int len) throws IOException;
    void flush() throws IOException;
    void close() throws IOException;
}
