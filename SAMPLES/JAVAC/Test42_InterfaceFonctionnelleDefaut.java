import java.util.*;
import java.util.function.*;
import java.util.concurrent.*;
public class Test42_InterfaceFonctionnelleDefaut {
    static class Ctx { <T> void put(Class<T> k, T v) { System.out.println(k.getSimpleName() + v.getClass().isSynthetic()); } }
    interface Info { long a(); default long b() { return 1; } }
    interface Sub extends Info { @Override default long a() { return 7; } Class<?> c(); }
    static <U> CompletableFuture<U> done(U u) { return CompletableFuture.completedFuture(u); }
    static String use(Sub s) { return s.c().getSimpleName() + s.a() + s.b(); }
    public static void main(String[] args) throws Exception {
        new Ctx().put(Runnable.class, () -> {});
        System.out.println(use(() -> String.class));
        CompletionStage<Supplier<String>> st = CompletableFuture.completedFuture("x").thenCompose(s -> done(() -> s + "!"));
        System.out.println(st.toCompletableFuture().get().get());
    }
}
