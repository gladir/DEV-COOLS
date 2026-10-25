import java.util.*;
import java.util.concurrent.Callable;
public class Test29_ThrowsGenerique {
    interface ThrowingSupplier<T, E extends Exception> { T get() throws E; }
    static <T, E extends Exception> T call(ThrowingSupplier<T, E> s) throws E { return s.get(); }
    static <X extends Throwable> void sneaky(Throwable t) throws X { throw (X) t; }
    public static void main(String[] args) throws Exception {
        System.out.println(call(() -> "ok"));
        try { String r = call(() -> { if (args.length == 0) throw new java.io.IOException("io"); return "x"; }); System.out.println(r); } catch (java.io.IOException e) { System.out.println("caught " + e.getMessage()); }
        try { Test29_ThrowsGenerique.<RuntimeException>sneaky(new Exception("sneaky")); } catch (Exception e) { System.out.println(e.getMessage()); }
    }
}
