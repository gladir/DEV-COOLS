package java.awt;
public abstract class GraphicsEnvironment {
    public static boolean isHeadless() { return !WM.ensureOpen(); }
}
