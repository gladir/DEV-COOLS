import java.util.*;
import java.io.*;
public class Test28_OrElseThrow {
    static class MyEx extends RuntimeException { MyEx(String s) { super(s); } }
    public static void main(String[] args) throws IOException {
        Optional<String> o = Optional.of("x");
        System.out.println(o.orElseThrow(() -> new MyEx("no")));
        System.out.println(o.orElseThrow(IllegalStateException::new));
        Optional<String> p = Optional.of("y");
        String s = p.orElseThrow(() -> new IOException("io"));
        o.map(x -> x.length()).orElseThrow(() -> new IllegalArgumentException("bad"));
        List.of(1).forEach(i -> Optional.of(i).orElseThrow(() -> new MyEx("z")));
    }
}
