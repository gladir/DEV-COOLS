package javax.swing;
public class UIManager {
    public static void setLookAndFeel(String name) { }
    public static void setLookAndFeel(Object laf) { }
    public static String getSystemLookAndFeelClassName() { return "javax.swing.plaf.metal.MetalLookAndFeel"; }
    public static String getCrossPlatformLookAndFeelClassName() { return "javax.swing.plaf.metal.MetalLookAndFeel"; }
    public static void put(Object k, Object v) { }
    public static Object get(Object k) { return null; }
    public static class LookAndFeelInfo { public String getName() { return "Metal"; } public String getClassName() { return "javax.swing.plaf.metal.MetalLookAndFeel"; } }
    public static LookAndFeelInfo[] getInstalledLookAndFeels() { return new LookAndFeelInfo[] { new LookAndFeelInfo() }; }
}
