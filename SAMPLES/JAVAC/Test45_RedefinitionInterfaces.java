public class Test45_RedefinitionInterfaces {
    interface JT {}
    interface RJT extends JT {}
    interface HRT extends RJT {}
    interface JM { JT dc(); }
    interface RJM extends JM { RJT dc(); }
    interface HM extends JM { }
    interface HRJM extends HM, RJM { HRT dc(); }
    static HRT f(HRJM m) { HRT h = m.dc(); return h; }
    public static void main(String[] args) { System.out.println("ok"); }
}
