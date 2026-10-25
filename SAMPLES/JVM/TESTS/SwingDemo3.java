import javax.swing.*;
import java.awt.*;
public class SwingDemo3 {
    public static void main(String[] a) throws Exception {
        JFrame f = new JFrame("Scroll tabs");
        f.setLayout(new GridLayout(2, 2));
        int[] pl = { JTabbedPane.TOP, JTabbedPane.BOTTOM, JTabbedPane.LEFT, JTabbedPane.RIGHT };
        JTabbedPane[] tp = new JTabbedPane[4];
        for (int k = 0; k < 4; k++) {
            tp[k] = new JTabbedPane(pl[k], JTabbedPane.SCROLL_TAB_LAYOUT);
            for (int i = 1; i <= 9; i++) tp[k].addTab("Onglet " + i, new JLabel("contenu " + i));
            tp[k].setPreferredSize(new Dimension(230, 120));
            f.add(tp[k]);
        }
        f.pack(); f.setVisible(true);
        Thread.sleep(1500);
        tp[0].setSelectedIndex(8); tp[1].setSelectedIndex(4); tp[2].setSelectedIndex(7); tp[3].setSelectedIndex(8);
        Thread.sleep(1500);
        System.out.println(tp[0].getBoundsAt(0) + " " + tp[0].getBoundsAt(8));
        Thread.sleep(5000);
        System.exit(0);
    }
}
