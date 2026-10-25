package java.awt;
public class EventQueue {
    public static void invokeLater(Runnable r) { WM.invokeLater(r); }
    public static void invokeAndWait(Runnable r) { r.run(); }
    public static boolean isDispatchThread() { return true; }
}
