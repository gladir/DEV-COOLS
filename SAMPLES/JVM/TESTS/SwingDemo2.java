import javax.swing.*;
import javax.swing.table.*;
import java.awt.*;
public class SwingDemo2 {
    public static void main(String[] a) throws Exception {
        JFrame f = new JFrame("SwingDemo2");
        f.setLayout(new GridBagLayout());
        JTextArea ta = new JTextArea(4, 25);
        for (int i = 1; i <= 12; i++) ta.append("ligne " + i + (i == 7 ? " avec une tres longue ligne qui depasse la largeur visible" : "") + "\n");
        JComboBox<String> cb = new JComboBox<>(new String[] { "Alpha", "Beta", "Gamma" });
        JTabbedPane tp = new JTabbedPane(JTabbedPane.BOTTOM);
        for (int i = 1; i <= 8; i++) tp.addTab("Onglet " + i, new JLabel("contenu " + i));
        tp.setPreferredSize(new Dimension(200, 90));
        JTabbedPane tl = new JTabbedPane(JTabbedPane.LEFT);
        tl.addTab("Un", new JLabel("a")); tl.addTab("Deux", new JLabel("b")); tl.addTab("Trois", new JLabel("c"));
        GridBagConstraints g = new GridBagConstraints();
        g.gridx = 0; g.gridy = 0; g.fill = GridBagConstraints.BOTH; g.weightx = 1; g.weighty = 1;
        f.add(new JScrollPane(ta), g);
        g.gridx = 1; f.add(tl, g);
        g.gridx = 0; g.gridy = 1; g.weighty = 0; g.fill = GridBagConstraints.HORIZONTAL; f.add(cb, g);
        g.gridx = 1; f.add(tp, g);
        f.pack(); f.setVisible(true);
        Point p = cb.getLocationOnScreen();
        System.out.println("combo " + p.x + "," + p.y + " " + cb.getSize() + " ta=" + ta.getSize() + " vp=" + ((JScrollPane) ta.getParent().getParent()).getViewport().getSize());
        Thread.sleep(6000);
        System.exit(0);
    }
}
