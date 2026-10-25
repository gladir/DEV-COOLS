import javax.swing.*;
import java.awt.*;
public class GridBag1 {
    static JPanel box(int w, int h, int mw, int mh) {
        JPanel p = new JPanel();
        p.setPreferredSize(new Dimension(w, h));
        p.setMinimumSize(new Dimension(mw, mh));
        return p;
    }
    static void dump(String t, JPanel p) {
        System.out.println("== " + t + " " + p.getPreferredSize() + " min=" + p.getMinimumSize());
        for (Component c : p.getComponents()) System.out.println("  " + c.getX() + "," + c.getY() + " " + c.getWidth() + "x" + c.getHeight());
    }
    static void add(JPanel p, Component c, int x, int y, int w, int h, double wx, double wy, int fill, int anchor, Insets in, int ipx, int ipy) {
        GridBagConstraints g = new GridBagConstraints();
        g.gridx = x; g.gridy = y; g.gridwidth = w; g.gridheight = h; g.weightx = wx; g.weighty = wy; g.fill = fill; g.anchor = anchor;
        if (in != null) g.insets = in; g.ipadx = ipx; g.ipady = ipy;
        p.add(c, g);
    }
    public static void main(String[] a) {
        JPanel p = new JPanel(new GridBagLayout());
        add(p, box(50, 20, 30, 10), 0, 0, 1, 1, 0, 0, 0, 10, new Insets(2, 3, 4, 5), 0, 0);
        add(p, box(80, 25, 40, 10), 1, 0, 2, 1, 1.0, 0, 2, 17, null, 0, 0);
        add(p, box(60, 60, 30, 30), 0, 1, 1, 2, 0, 1.0, 3, 13, new Insets(1, 1, 1, 1), 4, 2);
        add(p, box(70, 30, 30, 10), 1, 1, 1, 1, 0.5, 0.5, 1, 10, null, 0, 0);
        add(p, box(40, 40, 10, 10), 2, 1, 1, 1, 1.5, 0, 0, 12, null, 0, 0);
        add(p, box(100, 20, 10, 10), 1, 2, 2, 1, 0, 0, 0, 15, null, 0, 0);
        add(p, box(30, 30, 10, 10), GridBagConstraints.RELATIVE, GridBagConstraints.RELATIVE, GridBagConstraints.REMAINDER, 1, 0, 0, 0, 18, null, 0, 0);
        p.setSize(p.getPreferredSize());
        p.doLayout(); dump("pref", p);
        p.setSize(400, 300); p.doLayout(); dump("400x300", p);
        p.setSize(150, 80); p.doLayout(); dump("150x80", p);
        JPanel q = new JPanel(new GridBagLayout());
        GridBagConstraints g = new GridBagConstraints();
        g.fill = GridBagConstraints.HORIZONTAL; g.weightx = 1; g.insets = new Insets(2, 2, 2, 2);
        for (int i = 0; i < 6; i++) {
            g.gridx = i % 3; g.gridy = i / 3;
            if (i == 2) g.gridwidth = GridBagConstraints.REMAINDER; else g.gridwidth = 1;
            q.add(box(20 + i * 10, 10 + i * 3, 5, 5), g);
        }
        q.setSize(300, 200); q.doLayout(); dump("q", q);
        q.setSize(q.getPreferredSize()); q.doLayout(); dump("qpref", q);
        // sans contraintes et colonnes fixes
        GridBagLayout gl = new GridBagLayout();
        gl.columnWidths = new int[] { 40, 0, 60 }; gl.rowHeights = new int[] { 0, 25 }; gl.columnWeights = new double[] { 0, 1, 0 }; gl.rowWeights = new double[] { 1, 0 };
        JPanel r = new JPanel(gl);
        r.add(box(10, 10, 5, 5)); r.add(box(10, 10, 5, 5));
        r.setSize(200, 100); r.doLayout(); dump("r", r);
        System.out.println(gl.location(45, 10) + " " + java.util.Arrays.toString(gl.getLayoutDimensions()[0]) + java.util.Arrays.toString(gl.getLayoutWeights()[1]) + gl.getLayoutOrigin());
    }
}
