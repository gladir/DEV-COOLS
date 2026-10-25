import javax.swing.*;
import javax.swing.event.*;
import javax.swing.tree.*;
import java.awt.*;
public class SwingDemo4 {
    public static void main(String[] a) throws Exception {
        DefaultMutableTreeNode root = new DefaultMutableTreeNode("Projet");
        DefaultMutableTreeNode src = new DefaultMutableTreeNode("src");
        src.add(new DefaultMutableTreeNode("Main.java")); src.add(new DefaultMutableTreeNode("Util.java"));
        DefaultMutableTreeNode pk = new DefaultMutableTreeNode("modele");
        pk.add(new DefaultMutableTreeNode("Client.java")); pk.add(new DefaultMutableTreeNode("Commande.java"));
        src.add(pk);
        root.add(src);
        DefaultMutableTreeNode doc = new DefaultMutableTreeNode("doc"); doc.add(new DefaultMutableTreeNode("README.md")); root.add(doc);
        root.add(new DefaultMutableTreeNode("pom.xml"));
        JTree t = new JTree(root);
        t.setEditable(true);
        t.addTreeSelectionListener(e -> System.out.println("sel " + e.getNewLeadSelectionPath()));
        t.addTreeExpansionListener(new TreeExpansionListener() {
            public void treeExpanded(TreeExpansionEvent e) { System.out.println("exp " + e.getPath()); }
            public void treeCollapsed(TreeExpansionEvent e) { System.out.println("col " + e.getPath()); }
        });
        JFrame f = new JFrame("Arbre");
        JScrollPane sp = new JScrollPane(t);
        sp.setPreferredSize(new Dimension(220, 200));
        f.add(sp);
        f.pack(); f.setVisible(true);
        Point p = t.getLocationOnScreen();
        System.out.println("tree " + p.x + "," + p.y + " " + t.getSize() + " rows=" + t.getRowCount() + " b0=" + t.getRowBounds(0) + " b1=" + t.getRowBounds(1));
        Thread.sleep((a.length > 0 ? Integer.parseInt(a[0]) : 5000));
        System.out.println("end rows=" + t.getRowCount() + " sel=" + t.getSelectionPath() + " editing=" + t.isEditing() + " v=" + root.getChildAt(0).getChildAt(0));
        System.exit(0);
    }
}
