import javax.swing.*;
import javax.swing.table.*;
import java.awt.*;
public class SwingDemo1 {
    public static void main(String[] a) throws Exception {
        JFrame f = new JFrame("Swing demo");
        JTabbedPane tabs = new JTabbedPane();
        DefaultTableModel m = new DefaultTableModel(new Object[][] {
            { "pomme", 30, 1.5, true }, { "Banane", 5, 0.25, false }, { "cerise", 100, 12.0, true }, { "abricot", 7, 3.0, false }, { "Citron", 12, 0.5, true } },
            new Object[] { "Nom", "Quantite", "Prix", "Stock" }) {
            public Class<?> getColumnClass(int c) { return c == 0 ? String.class : c == 1 ? Integer.class : c == 2 ? Double.class : Boolean.class; }
        };
        JTable t = new JTable(m);
        t.setAutoCreateRowSorter(true);
        t.setPreferredScrollableViewportSize(new Dimension(380, 120));
        tabs.addTab("Table", new JScrollPane(t));
        JPanel form = new JPanel(new GridBagLayout());
        GridBagConstraints g = new GridBagConstraints();
        g.insets = new Insets(4, 4, 4, 4);
        g.gridx = 0; g.gridy = 0; g.anchor = GridBagConstraints.EAST; form.add(new JLabel("Nom :"), g);
        g.gridx = 1; g.weightx = 1; g.fill = GridBagConstraints.HORIZONTAL; form.add(new JTextField("Dupont", 12), g);
        g.gridx = 0; g.gridy = 1; g.weightx = 0; g.fill = GridBagConstraints.NONE; form.add(new JLabel("Ville :"), g);
        g.gridx = 1; g.weightx = 1; g.fill = GridBagConstraints.HORIZONTAL; form.add(new JComboBox<String>(new String[] { "Paris", "Lyon", "Nice" }), g);
        g.gridx = 0; g.gridy = 2; g.gridwidth = 2; g.weighty = 1; g.fill = GridBagConstraints.BOTH; form.add(new JScrollPane(new JTextArea("Notes...\nligne 2", 4, 20)), g);
        g.gridy = 3; g.weighty = 0; g.gridwidth = 1; g.gridx = 1; g.fill = GridBagConstraints.NONE; g.anchor = GridBagConstraints.EAST; form.add(new JButton("OK"), g);
        tabs.addTab("Formulaire", form);
        DefaultListModel<String> lm = new DefaultListModel<>();
        for (int i = 1; i <= 15; i++) lm.addElement("Element " + i);
        JList<String> l = new JList<>(lm);
        JSplitPane sp = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, new JScrollPane(l), new JScrollPane(new JTextArea("Panneau droit\nSplitPane", 6, 20)));
        sp.setDividerLocation(120);
        sp.setOneTouchExpandable(true);
        tabs.addTab("Split", sp);
        tabs.addTab("Vide", new JLabel("vide"));
        tabs.setEnabledAt(3, false);
        f.add(tabs);
        f.pack();
        f.setVisible(true);
        System.out.println("size " + f.getWidth() + "x" + f.getHeight() + " tabs=" + tabs.getSize() + " tab0=" + tabs.getBoundsAt(0) + " tab1=" + tabs.getBoundsAt(1));
        for (int i = 0; i < 3; i++) { tabs.setSelectedIndex(i); Thread.sleep(2500); }
        System.exit(0);
    }
}
