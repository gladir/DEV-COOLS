import javax.swing.*;
import javax.swing.event.*;
import javax.swing.tree.*;
import java.io.*;
import java.util.*;
public class Tree1 {
    static boolean showLead = true;
    static void p(String s) { System.out.println(s); }
    static String rows(JTree t) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < t.getRowCount(); i++) sb.append(t.getPathForRow(i).getLastPathComponent()).append(i < t.getRowCount() - 1 ? "," : "");
        return sb.toString();
    }
    static String sel(JTree t) {
        TreePath[] s = t.getSelectionPaths();
        StringBuilder sb = new StringBuilder("[");
        if (s != null) { String[] ss = new String[s.length]; for (int i = 0; i < s.length; i++) ss[i] = s[i].toString(); Arrays.sort(ss); for (String x : ss) sb.append(x).append(";"); }
        int[] rr = t.getSelectionRows(); if (rr != null) Arrays.sort(rr);
        return sb + "] rows=" + Arrays.toString(rr) + (showLead ? " lead=" + t.getLeadSelectionPath() + "/" + t.getLeadSelectionRow() + " anchor=" + t.getAnchorSelectionPath() : "") + " min=" + t.getMinSelectionRow() + " max=" + t.getMaxSelectionRow();
    }
    static DefaultMutableTreeNode n(Object o, DefaultMutableTreeNode... kids) { DefaultMutableTreeNode x = new DefaultMutableTreeNode(o); for (DefaultMutableTreeNode k : kids) x.add(k); return x; }
    public static void main(String[] a) throws Exception {
        JTree t = new JTree();
        p("default rows=" + t.getRowCount() + " " + rows(t) + " rv=" + t.isRootVisible() + " rh=" + t.getShowsRootHandles() + " h=" + t.getRowHeight() + " vrc=" + t.getVisibleRowCount() + " tc=" + t.getToggleClickCount() + " sce=" + t.getScrollsOnExpand() + " esp=" + t.getExpandsSelectedPaths());
        TreeModel m = t.getModel();
        DefaultMutableTreeNode root = (DefaultMutableTreeNode) m.getRoot();
        t.addTreeExpansionListener(new TreeExpansionListener() {
            public void treeExpanded(TreeExpansionEvent e) { p("expanded " + e.getPath() + " src=" + (e.getSource() == t)); }
            public void treeCollapsed(TreeExpansionEvent e) { p("collapsed " + e.getPath()); }
        });
        t.addTreeSelectionListener(e -> {
            StringBuilder sb = new StringBuilder("sel-event ");
            String[] ss = new String[e.getPaths().length];
            for (int i = 0; i < ss.length; i++) ss[i] = e.getPaths()[i].toString() + (e.isAddedPath(i) ? "+" : "-");
            Arrays.sort(ss); for (String x : ss) sb.append(x).append(' ');
            p(sb + (showLead ? "old=" + e.getOldLeadSelectionPath() + " new=" + e.getNewLeadSelectionPath() : "") + " src=" + (e.getSource() == t));
        });
        t.expandRow(0); p("expandRow0 " + rows(t));
        t.expandRow(1); p("expandRow1 " + rows(t) + " n=" + t.getRowCount());
        t.expandRow(6); p("expandRow6 " + rows(t));
        p("isExpanded " + t.isExpanded(1) + t.isExpanded(0) + t.isExpanded(new TreePath(root).pathByAddingChild(root.getChildAt(2))) + " col " + t.isCollapsed(2));
        t.setSelectionRow(2); p("selrow2 " + sel(t));
        t.addSelectionRow(8); p("addrow8 " + sel(t));
        t.addSelectionInterval(3, 5); p("addint " + sel(t));
        showLead = false; t.removeSelectionRow(4); p("remrow4 " + sel(t));
        t.setSelectionInterval(1, 2); p("setint " + sel(t));
        t.collapseRow(1); p("collapse1 " + rows(t) + " " + sel(t));
        t.collapseRow(0); p("collapse0 " + rows(t) + " " + sel(t));
        t.expandPath(new TreePath(root)); p("expand root " + rows(t));
        TreePath deep = new TreePath(new Object[] { root, root.getChildAt(1), root.getChildAt(1).getChildAt(2) });
        t.setSelectionPath(deep); p("selDeep " + sel(t) + " rows=" + rows(t));
        t.collapsePath(new TreePath(new Object[] { root, root.getChildAt(1) })); p("collapse parent of sel " + sel(t));
        t.scrollPathToVisible(deep); p("visible " + t.isVisible(deep) + " " + rows(t));
        t.clearSelection(); showLead = true; p("clear " + sel(t));
        p("exp desc " + Collections.list(t.getExpandedDescendants(new TreePath(root))).size() + " hasBeen " + t.hasBeenExpanded(new TreePath(new Object[] { root, root.getChildAt(0) })));
        p("closest/row " + t.getRowForPath(deep) + " " + t.getRowForPath(new TreePath("zz")) + " " + t.getPathForRow(99) + " " + t.getPathForRow(-1));
        p("match " + t.getNextMatch("s", 0, javax.swing.text.Position.Bias.Forward) + " " + t.getNextMatch("b", 5, javax.swing.text.Position.Bias.Forward) + " " + t.getNextMatch("zzz", 0, javax.swing.text.Position.Bias.Forward) + " " + t.getNextMatch("f", 6, javax.swing.text.Position.Bias.Backward));
        // veto
        t.addTreeWillExpandListener(new TreeWillExpandListener() {
            public void treeWillExpand(TreeExpansionEvent e) throws ExpandVetoException { p("will expand " + e.getPath()); if (e.getPath().getLastPathComponent().toString().equals("sports")) throw new ExpandVetoException(e, "no"); }
            public void treeWillCollapse(TreeExpansionEvent e) throws ExpandVetoException { p("will collapse " + e.getPath()); }
        });
        t.collapseRow(0); t.expandRow(0); t.expandRow(2); p("veto " + rows(t) + " " + t.isExpanded(2));
        t.collapsePath(new TreePath(root)); t.expandPath(new TreePath(new Object[] { root, root.getChildAt(1), root.getChildAt(1).getChildAt(0) })); p("expand leaf " + rows(t));
        // modele
        DefaultTreeModel dm = (DefaultTreeModel) t.getModel();
        dm.addTreeModelListener(new TreeModelListener() {
            public void treeNodesChanged(TreeModelEvent e) { p("changed " + e.getTreePath() + " " + Arrays.toString(e.getChildIndices()) + " " + Arrays.toString(e.getChildren())); }
            public void treeNodesInserted(TreeModelEvent e) { p("inserted " + e.getTreePath() + " " + Arrays.toString(e.getChildIndices()) + " " + Arrays.toString(e.getChildren())); }
            public void treeNodesRemoved(TreeModelEvent e) { p("removed " + e.getTreePath() + " " + Arrays.toString(e.getChildIndices()) + " " + Arrays.toString(e.getChildren())); }
            public void treeStructureChanged(TreeModelEvent e) { p("structure " + e.getTreePath() + " " + Arrays.toString(e.getChildIndices()) + " " + e.getChildren()); }
        });
        t.expandRow(0); t.expandRow(1); t.expandRow(6);
        t.setSelectionRow(3); p("before model change " + rows(t) + " " + sel(t));
        DefaultMutableTreeNode colors = (DefaultMutableTreeNode) root.getChildAt(0);
        dm.insertNodeInto(new DefaultMutableTreeNode("green"), colors, 1); p("insert " + rows(t) + " " + sel(t));
        dm.removeNodeFromParent((DefaultMutableTreeNode) colors.getChildAt(0)); p("remove " + rows(t) + " " + sel(t));
        dm.valueForPathChanged(new TreePath(new Object[] { root, colors }), "COLORS"); p("changed " + rows(t));
        dm.nodeStructureChanged(colors); p("structure colors " + rows(t) + " " + sel(t) + " expanded=" + t.isExpanded(new TreePath(new Object[] { root, colors })));
        dm.reload(); p("reload " + rows(t) + " " + sel(t));
        DefaultMutableTreeNode food = (DefaultMutableTreeNode) root.getChildAt(2);
        t.expandPath(new TreePath(new Object[] { root, food })); t.setSelectionPath(new TreePath(new Object[] { root, food, food.getChildAt(1) }));
        while (food.getChildCount() > 0) dm.removeNodeFromParent((DefaultMutableTreeNode) food.getChildAt(0));
        p("food emptied " + rows(t) + " " + sel(t) + " exp=" + t.isExpanded(new TreePath(new Object[] { root, food })));
        // racine invisible et poignees
        JTree t2 = new JTree(new Object[] { "alpha", new Vector<Object>(Arrays.asList("beta", "gamma", new Vector<Object>(Arrays.asList("d1", "d2")))), "omega" });
        p("array tree " + t2.getRowCount() + " " + rows(t2) + " rv=" + t2.isRootVisible() + " rh=" + t2.getShowsRootHandles() + " root=" + t2.getModel().getRoot() + " leaf=" + t2.getModel().isLeaf(t2.getModel().getRoot()) + " " + ((DefaultTreeModel) t2.getModel()).asksAllowsChildren());
        t2.expandRow(1); p("expand1 " + rows(t2)); t2.expandRow(4); p("expand4 " + rows(t2));
        t2.setRootVisible(true); p("rootVisible " + rows(t2) + " " + t2.getRowForPath(new TreePath(t2.getModel().getRoot())));
        t2.setRootVisible(false); t2.collapsePath(new TreePath(t2.getModel().getRoot())); p("root collapsed invisible " + t2.getRowCount() + " " + rows(t2));
        Hashtable<String, Object> ht = new Hashtable<>(); ht.put("one", new String[] { "a", "b" }); ht.put("two", "leaf");
        JTree t3 = new JTree(ht); p("hashtable tree " + t3.getRowCount() + " " + t3.getModel().getChildCount(t3.getModel().getRoot()));
        JTree t4 = new JTree(new DefaultMutableTreeNode("solo")); p("solo " + t4.getRowCount() + " " + rows(t4) + " leaf=" + t4.getModel().isLeaf(t4.getModel().getRoot()));
        JTree t5 = new JTree((TreeModel) null == null ? new DefaultTreeModel(null) : null); p("null root rows " + t5.getRowCount());
        // modes de selection
        JTree t6 = new JTree();
        t6.expandRow(0); t6.expandRow(1);
        t6.getSelectionModel().setSelectionMode(TreeSelectionModel.SINGLE_TREE_SELECTION);
        t6.setSelectionRows(new int[] { 2, 4 }); p("single " + sel(t6));
        t6.getSelectionModel().setSelectionMode(TreeSelectionModel.CONTIGUOUS_TREE_SELECTION);
        t6.setSelectionRows(new int[] { 2, 3 }); p("contig ok " + sel(t6));
        t6.setSelectionRows(new int[] { 2, 5 }); p("contig gap " + sel(t6));
        t6.addSelectionRow(3); p("contig add adjacent " + sel(t6));
        t6.addSelectionRow(7); p("contig add far " + sel(t6));
        t6.getSelectionModel().setSelectionMode(TreeSelectionModel.DISCONTIGUOUS_TREE_SELECTION);
        t6.setSelectionRows(new int[] { 1, 3, 5 }); t6.removeSelectionRow(3); p("discontig " + sel(t6));
        t6.setSelectionModel(null); t6.setSelectionRow(1); p("empty model " + sel(t6) + " " + t6.getSelectionModel().getClass().getSimpleName());
        t6.getSelectionModel().addPropertyChangeListener(e -> p("never"));
        DefaultTreeSelectionModel dsm = new DefaultTreeSelectionModel();
        dsm.addPropertyChangeListener(e -> p("prop " + e.getPropertyName() + " " + e.getOldValue() + "->" + e.getNewValue()));
        dsm.setSelectionMode(TreeSelectionModel.SINGLE_TREE_SELECTION); dsm.setSelectionMode(99); p("mode " + dsm.getSelectionMode());
        // noeuds
        DefaultMutableTreeNode r = n("r", n("a", n("a1"), n("a2", n("a21"))), n("b"), n("c", n("c1"), n("c2")));
        StringBuilder sb = new StringBuilder();
        for (Enumeration<TreeNode> e = r.preorderEnumeration(); e.hasMoreElements(); ) sb.append(e.nextElement()).append(' ');
        sb.append("| ");
        for (Enumeration<TreeNode> e = r.postorderEnumeration(); e.hasMoreElements(); ) sb.append(e.nextElement()).append(' ');
        sb.append("| ");
        for (Enumeration<TreeNode> e = r.breadthFirstEnumeration(); e.hasMoreElements(); ) sb.append(e.nextElement()).append(' ');
        p(sb.toString());
        DefaultMutableTreeNode a21 = (DefaultMutableTreeNode) ((DefaultMutableTreeNode) r.getFirstChild()).getChildAt(1).getChildAt(0);
        DefaultMutableTreeNode c2 = (DefaultMutableTreeNode) ((DefaultMutableTreeNode) r.getLastChild()).getLastChild();
        p("depth=" + r.getDepth() + " level=" + a21.getLevel() + " leaves=" + r.getLeafCount() + " path=" + Arrays.toString(a21.getPath()) + " shared=" + a21.getSharedAncestor(c2) + " next=" + a21.getNextNode() + " prev=" + c2.getPreviousNode() + " nextleaf=" + a21.getNextLeaf() + " prevleaf=" + c2.getPreviousLeaf() + " firstleaf=" + r.getFirstLeaf() + " lastleaf=" + r.getLastLeaf());
        p("siblings " + c2.getNextSibling() + " " + c2.getPreviousSibling() + " " + c2.getSiblingCount() + " " + a21.isNodeAncestor(r) + " " + r.isNodeDescendant(a21) + " " + a21.isNodeRelated(c2) + " " + r.isRoot() + a21.isRoot() + " " + r.getChildAfter(r.getFirstChild()) + " " + r.getIndex(c2.getParent()));
        for (Enumeration<TreeNode> e = a21.pathFromAncestorEnumeration(r); e.hasMoreElements(); ) System.out.print(e.nextElement() + " ");
        System.out.println();
        try { ((DefaultMutableTreeNode) r.getFirstChild()).getChildAt(0).getChildAt(0); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        try { a21.add(r); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        try { r.add(r); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        try { new DefaultMutableTreeNode("x", false).add(new DefaultMutableTreeNode()); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        try { r.remove((javax.swing.tree.MutableTreeNode) a21); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        DefaultMutableTreeNode cl = (DefaultMutableTreeNode) r.clone(); p("clone " + cl + " " + cl.getChildCount() + " " + cl.getParent());
        DefaultMutableTreeNode mv = n("m"); r.add(mv);  ((DefaultMutableTreeNode) r.getChildAt(1)).add(mv); p("move " + r.getChildCount() + " " + r.getChildAt(1).getChildCount() + " " + mv.getParent());
        ((DefaultMutableTreeNode) r.getChildAt(1)).setAllowsChildren(false); p("allows false " + r.getChildAt(1).getChildCount());
        // TreePath
        TreePath tp = new TreePath(new Object[] { "a", "b", "c" });
        p(tp + " " + tp.getPathCount() + " " + tp.getParentPath() + " " + tp.equals(new TreePath(new Object[] { "a", "b", "c" })) + " " + tp.isDescendant(new TreePath(new Object[] { "a", "b", "c", "d" })) + " " + tp.isDescendant(tp.getParentPath()) + " " + tp.pathByAddingChild("d") + " " + (tp.hashCode() == "c".hashCode()) + " " + tp.getPathComponent(1));
        try { tp.getPathComponent(5); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        try { new TreePath(new Object[0]); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        // serialisation
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        ObjectOutputStream oo = new ObjectOutputStream(bo);
        DefaultMutableTreeNode sr = n("serial", n("x1", n("y")), n("x2"));
        oo.writeObject(sr); oo.close();
        byte[] bytes = bo.toByteArray();
        int h = 0; for (byte b : bytes) h = h * 31 + b;
        p("ser " + bytes.length + " " + h);
        DefaultMutableTreeNode back = (DefaultMutableTreeNode) new ObjectInputStream(new ByteArrayInputStream(bytes)).readObject();
        p("deser " + back + " " + back.getChildCount() + " " + ((DefaultMutableTreeNode) back.getFirstChild()).getChildAt(0) + " " + back.getFirstChild().getParent());
        // editeur
        DefaultMutableTreeNode er = n("root", n("e1"), n("e2"));
        JTree et = new JTree(er); et.setEditable(true); et.expandRow(0);
        p("editor " + et.getCellEditor().getClass().getSimpleName() + " " + et.isEditing() + " " + et.getCellRenderer().getClass().getSimpleName());
        et.setSelectionRow(1); et.startEditingAtPath(et.getPathForRow(1));
        p("editing " + et.isEditing() + " " + et.getEditingPath());
        et.cancelEditing(); p("cancel " + et.isEditing());
        p("props " + et.getRowHeight());
    }
}
