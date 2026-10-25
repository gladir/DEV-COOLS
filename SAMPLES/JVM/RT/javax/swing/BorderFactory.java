package javax.swing;
import java.awt.*;
import javax.swing.border.*;
public class BorderFactory {
    public static Border createEmptyBorder() { return new EmptyBorder(0, 0, 0, 0); }
    public static Border createEmptyBorder(int top, int left, int bottom, int right) { return new EmptyBorder(top, left, bottom, right); }
    public static Border createLineBorder(Color color) { return new LineBorder(color); }
    public static Border createLineBorder(Color color, int thickness) { return new LineBorder(color, thickness); }
    public static Border createLineBorder(Color color, int thickness, boolean rounded) { return new LineBorder(color, thickness, rounded); }
    public static Border createBevelBorder(int type) { return new BevelBorder(type); }
    public static Border createRaisedBevelBorder() { return new BevelBorder(BevelBorder.RAISED); }
    public static Border createLoweredBevelBorder() { return new BevelBorder(BevelBorder.LOWERED); }
    public static Border createEtchedBorder() { return new EtchedBorder(); }
    public static Border createEtchedBorder(int t) { return new EtchedBorder(t); }
    public static TitledBorder createTitledBorder(String title) { return new TitledBorder(title); }
    public static TitledBorder createTitledBorder(Border b, String title) { return new TitledBorder(title); }
    public static Border createCompoundBorder(Border outside, Border inside) { return new CompoundBorder(outside, inside); }
}
