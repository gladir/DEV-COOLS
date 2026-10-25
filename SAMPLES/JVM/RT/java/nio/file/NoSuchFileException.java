package java.nio.file;
public class NoSuchFileException extends java.io.IOException {
    private static final long serialVersionUID = -1390291775875351931L;
    public NoSuchFileException(String file) { super(file); }
}
