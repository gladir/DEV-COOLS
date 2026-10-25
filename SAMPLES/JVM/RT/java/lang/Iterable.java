package java.lang;
import java.util.Iterator;
import java.util.function.Consumer;
public interface Iterable<T> {
    Iterator<T> iterator();
    default void forEach(Consumer<? super T> action) {
        for (T t : this) action.accept(t);
    }
    default java.util.Spliterator<T> spliterator() { return null; }
}
