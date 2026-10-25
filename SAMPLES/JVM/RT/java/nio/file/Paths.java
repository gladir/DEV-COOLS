package java.nio.file;
public final class Paths {
    private Paths() {}
    public static Path get(String first, String... more) { return Path.of(first, more); }
}
