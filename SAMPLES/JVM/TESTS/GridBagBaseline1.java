import javax.swing.*;
import java.awt.*;
public class GridBagBaseline1 {
    static void dump(String t, JPanel p) {
        System.out.println("== " + t + " " + p.getPreferredSize() + " min=" + p.getMinimumSize());
        for (Component c : p.getComponents()) System.out.println("  " + c.getX() + "," + c.getY() + " " + c.getWidth() + "x" + c.getHeight());
    }
    static Component.BaselineResizeBehavior[] all = { Component.BaselineResizeBehavior.CONSTANT_ASCENT, Component.BaselineResizeBehavior.CONSTANT_DESCENT, Component.BaselineResizeBehavior.CENTER_OFFSET, Component.BaselineResizeBehavior.OTHER };
    static void add(JPanel p, Component c, int x, int y, int w, int h, double wx, double wy, int fill, int anchor, Insets in, int ipx, int ipy) {
        GridBagConstraints g = new GridBagConstraints();
        g.gridx = x; g.gridy = y; g.gridwidth = w; g.gridheight = h; g.weightx = wx; g.weighty = wy; g.fill = fill; g.anchor = anchor;
        if (in != null) g.insets = in; g.ipadx = ipx; g.ipady = ipy;
        p.add(c, g);
    }
    static Component mk(int w, int h, int base, int brb) { return new B2(w, h, base, all[brb]); }
    static class B2 extends JPanel {
        final int base; final Component.BaselineResizeBehavior brb;
        B2(int w, int h, int base, Component.BaselineResizeBehavior brb) { this.base = base; this.brb = brb; setPreferredSize(new Dimension(w, h)); setMinimumSize(new Dimension(w, h)); }
        public int getBaseline(int w, int h) {
            switch (brb) {
                case CONSTANT_ASCENT: return base;
                case CONSTANT_DESCENT: return h - (getPreferredSize().height - base);
                case CENTER_OFFSET: return h / 2 + (base - getPreferredSize().height / 2);
                default: return base < 0 ? -1 : base + (h - getPreferredSize().height) / 3;
            }
        }
        public Component.BaselineResizeBehavior getBaselineResizeBehavior() { return brb; }
    }
    public static void main(String[] a) {
        int[] anchors = { GridBagConstraints.BASELINE, GridBagConstraints.BASELINE_LEADING, GridBagConstraints.BASELINE_TRAILING, GridBagConstraints.ABOVE_BASELINE, GridBagConstraints.BELOW_BASELINE, GridBagConstraints.ABOVE_BASELINE_TRAILING, GridBagConstraints.BELOW_BASELINE_LEADING };
        int[] fills = { 0, 1, 2, 3 };
        long seed = 12345;
        java.util.Random rnd = new java.util.Random(seed);
        for (int test = 0; test < 60; test++) {
            JPanel p = new JPanel(new GridBagLayout());
            int n = 2 + rnd.nextInt(5);
            for (int i = 0; i < n; i++) {
                int w = 20 + rnd.nextInt(60), h = 10 + rnd.nextInt(40);
                int base = rnd.nextInt(8) == 0 ? -1 : 4 + rnd.nextInt(Math.max(1, h - 6));
                int brb = rnd.nextInt(4);
                int x = rnd.nextInt(3), y = rnd.nextInt(3);
                int gw = 1 + (rnd.nextInt(5) == 0 ? 1 : 0), gh = 1 + (rnd.nextInt(5) == 0 ? 1 : 0);
                double wy = rnd.nextInt(3) == 0 ? rnd.nextInt(3) : 0;
                Insets in = rnd.nextBoolean() ? new Insets(rnd.nextInt(4), rnd.nextInt(4), rnd.nextInt(4), rnd.nextInt(4)) : null;
                int anchor = rnd.nextInt(4) == 0 ? GridBagConstraints.CENTER : anchors[rnd.nextInt(anchors.length)];
                add(p, mk(w, h, base, brb), x, y, gw, gh, rnd.nextInt(2), wy, fills[rnd.nextInt(4)], anchor, in, rnd.nextInt(3) == 0 ? 3 : 0, rnd.nextInt(3) == 0 ? 4 : 0);
            }
            p.setSize(p.getPreferredSize()); p.doLayout(); dump("t" + test + " pref", p);
            p.setSize(p.getPreferredSize().width + 37, p.getPreferredSize().height + 53); p.doLayout(); dump("t" + test + " big", p);
            p.setSize(p.getPreferredSize().width - 5, p.getPreferredSize().height - 5); p.doLayout(); dump("t" + test + " small", p);
        }
    }
}
