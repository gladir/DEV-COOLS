package java.util.stream;
import java.util.Iterator;
public interface BaseStream<T, S extends BaseStream<T, S>> extends AutoCloseable {
    Iterator<T> iterator();
    boolean isParallel();
    S sequential();
    S parallel();
    S unordered();
    S onClose(Runnable closeHandler);
    void close();
}
