import java.awt.*;
public class Test36_SwitchEnumBibliotheque {
    static String f(Component c) {
        switch (c.getBaselineResizeBehavior()) {
            case CONSTANT_DESCENT: return "d";
            case CONSTANT_ASCENT: return "a";
            default: return "o";
        }
    }
    public static void main(String[] args) { System.out.println(f(new Button("x"))); }
}
