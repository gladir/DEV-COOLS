import javax.swing.*;
import javax.swing.event.*;
import javax.swing.table.*;
import java.awt.*;
import java.util.*;
public class Table1 {
    static void p(String s) { System.out.println(s); }
    static String widths(JTable t) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < t.getColumnCount(); i++) sb.append(t.getColumnModel().getColumn(i).getWidth()).append(' ');
        return sb.toString();
    }
    static String rows(JTable t) {
        StringBuilder sb = new StringBuilder();
        for (int r = 0; r < t.getRowCount(); r++) sb.append(t.getValueAt(r, 0)).append(r < t.getRowCount() - 1 ? "," : "");
        return sb.toString();
    }
    static String sel(JTable t) { return Arrays.toString(t.getSelectedRows()) + "/" + Arrays.toString(t.getSelectedColumns()) + " lead=" + t.getSelectionModel().getLeadSelectionIndex(); }
    public static void main(String[] a) throws Exception {
        DefaultTableModel m = new DefaultTableModel(new Object[][] {
            { "pomme", 30, 1.5 }, { "Banane", 5, 0.25 }, { "cerise", 100, 12.0 }, { "abricot", 7, 3.0 }, { "Citron", 12, 0.5 } },
            new Object[] { "Nom", "Qte", "Prix" }) {
            public Class<?> getColumnClass(int c) { return c == 0 ? String.class : c == 1 ? Integer.class : Double.class; }
        };
        JTable t = new JTable(m);
        p("rows=" + t.getRowCount() + " cols=" + t.getColumnCount() + " h=" + t.getRowHeight() + " " + t.getPreferredSize() + " vp=" + t.getPreferredScrollableViewportSize());
        t.setSize(300, 80); t.doLayout(); p("w300 " + widths(t));
        t.setSize(200, 80); t.doLayout(); p("w200 " + widths(t));
        t.setSize(100, 80); t.doLayout(); p("w100 " + widths(t));
        t.setSize(600, 80); t.doLayout(); p("w600 " + widths(t));
        t.getColumnModel().getColumn(0).setPreferredWidth(150);
        t.getColumnModel().getColumn(1).setMaxWidth(80);
        t.setSize(400, 80); t.doLayout(); p("w400 " + widths(t));
        t.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);
        t.setSize(500, 80); t.doLayout(); p("off " + widths(t) + t.getPreferredSize());
        t.setAutoResizeMode(JTable.AUTO_RESIZE_SUBSEQUENT_COLUMNS);
        t.getColumnModel().getColumn(0).setPreferredWidth(75); t.getColumnModel().getColumn(1).setMaxWidth(2000000000);
        t.setSize(300, 80); t.doLayout();
        p("cell " + t.getCellRect(2, 1, true) + t.getCellRect(2, 1, false) + " at " + t.rowAtPoint(new Point(10, 50)) + "," + t.columnAtPoint(new Point(150, 5)) + "," + t.columnAtPoint(new Point(310, 5)));
        // selection
        t.setRowSelectionInterval(1, 2); p("sel " + sel(t));
        t.changeSelection(3, 1, false, false); p("sel " + sel(t) + " col=" + t.getSelectedColumn());
        t.changeSelection(4, 1, false, true); p("ext " + sel(t));
        t.changeSelection(0, 1, true, false); p("tog " + sel(t));
        t.setSelectionMode(ListSelectionModel.SINGLE_SELECTION); p("single " + sel(t));
        t.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
        t.setRowSelectionInterval(1, 3);
        // model changes
        final StringBuilder ev = new StringBuilder();
        m.addTableModelListener(e -> ev.append(e.getType() + ":" + e.getFirstRow() + "-" + e.getLastRow() + "/" + e.getColumn() + " "));
        m.insertRow(0, new Object[] { "kiwi", 1, 0.1 }); p("ins " + rows(t) + " " + sel(t));
        m.removeRow(2); p("del " + rows(t) + " " + sel(t));
        m.setValueAt("zzz", 0, 0); m.addRow(new Object[] { "fin", 1, 1.0 }); m.removeRow(m.getRowCount() - 1); p(ev.toString());
        // tri
        t.setAutoCreateRowSorter(true);
        RowSorter<? extends TableModel> rs = t.getRowSorter();
        t.setRowSelectionInterval(2, 2); p("before sort sel " + sel(t) + " " + rows(t));
        rs.toggleSortOrder(0); p("asc0 " + rows(t) + " " + sel(t) + " keys=" + rs.getSortKeys().size());
        rs.toggleSortOrder(0); p("desc0 " + rows(t) + " " + sel(t));
        rs.toggleSortOrder(1); p("asc1 " + rows(t) + " vtm=" + t.convertRowIndexToModel(0) + " mtv=" + t.convertRowIndexToView(0));
        rs.toggleSortOrder(2); p("asc2 " + rows(t) + " keys=" + rs.getSortKeys().size());
        ((TableRowSorter<TableModel>) rs).setRowFilter(RowFilter.regexFilter("(?i)^c", 0)); p("filter " + rows(t) + " n=" + t.getRowCount() + " mrc=" + rs.getModelRowCount());
        ((TableRowSorter<TableModel>) rs).setRowFilter(RowFilter.numberFilter(RowFilter.ComparisonType.AFTER, 10, 1)); p("nfilter " + rows(t));
        ((TableRowSorter<TableModel>) rs).setRowFilter(null);
        m.addRow(new Object[] { "ananas", 50, 2.0 }); p("added " + rows(t));
        t.setRowSelectionInterval(0, 0); m.removeRow(t.convertRowIndexToModel(0)); p("removed " + rows(t) + " " + sel(t));
        t.setRowSorter(null);
        // colonnes
        t.moveColumn(0, 2); p("moved " + t.getColumnName(0) + t.getColumnName(1) + t.getColumnName(2) + " " + t.convertColumnIndexToModel(0) + " " + t.convertColumnIndexToView(0) + " val=" + t.getValueAt(0, 0));
        TableColumn tc = t.getColumn("Nom"); t.removeColumn(tc); p("rm " + t.getColumnCount() + " " + t.getColumnName(0));
        t.addColumn(tc); p("add " + t.getColumnCount() + " " + t.getColumnName(2));
        // edition
        JTable e = new JTable(new DefaultTableModel(new Object[][] { { "a", 1, true }, { "b", 2, false } }, new Object[] { "S", "I", "B" }) {
            public Class<?> getColumnClass(int c) { return c == 0 ? String.class : c == 1 ? Integer.class : Boolean.class; }
        });
        e.setSize(300, 50); e.doLayout();
        p("edit " + e.editCellAt(0, 1) + " " + e.isEditing() + " " + e.getEditingRow() + "," + e.getEditingColumn() + " " + e.getEditorComponent().getClass().getSimpleName() + " " + e.getEditorComponent().getBounds());
        ((JTextField) e.getEditorComponent()).setText("42x"); p("stop " + e.getCellEditor().stopCellEditing() + " " + e.isEditing());
        ((JTextField) e.getEditorComponent()).setText("42"); p("stop " + e.getCellEditor().stopCellEditing() + " " + e.isEditing() + " v=" + e.getValueAt(0, 1) + " " + e.getValueAt(0, 1).getClass().getSimpleName());
        e.editCellAt(1, 0); ((JTextField) e.getEditorComponent()).setText("zz"); e.getCellEditor().cancelCellEditing(); p("cancel " + e.getValueAt(1, 0));
        e.editCellAt(1, 2); ((JCheckBox) e.getEditorComponent()).setSelected(true); e.getCellEditor().stopCellEditing(); p("bool " + e.getValueAt(1, 2));
        p("renderers " + e.getDefaultRenderer(Object.class).getClass().getSimpleName() + " " + e.getCellRenderer(0, 1).getClass().getSimpleName() + " " + e.getCellRenderer(0, 2).getClass().getSimpleName() + " " + e.getCellRenderer(0, 0).getClass().getSimpleName());
        p("editors " + e.getCellEditor(0, 1).getClass().getSimpleName() + " " + e.getCellEditor(0, 2).getClass().getSimpleName() + " " + e.getCellEditor(0, 0).getClass().getSimpleName());
        // modele abstrait
        AbstractTableModel am = new AbstractTableModel() {
            public int getRowCount() { return 3; } public int getColumnCount() { return 30; }
            public Object getValueAt(int r, int c) { return r * c; }
        };
        p(am.getColumnName(0) + am.getColumnName(25) + am.getColumnName(26) + am.getColumnName(27) + am.getColumnName(701) + am.getColumnName(702) + " " + am.findColumn("AB"));
        JTable ct = new JTable(am);
        p("cols " + ct.getColumnCount() + " " + ct.getColumnName(28) + " " + ct.getValueAt(2, 5));
        DefaultTableModel dm = new DefaultTableModel(2, 2);
        dm.addColumn("X"); dm.addColumn("Y", new Object[] { 1, 2, 3 }); p(dm.getRowCount() + "x" + dm.getColumnCount() + " " + dm.getValueAt(2, 3) + " " + dm.getColumnName(0) + dm.getColumnName(2));
        dm.moveRow(0, 1, 1); dm.setRowCount(1); p(dm.getRowCount() + "");
        // listeners
        t.addPropertyChangeListener("rowHeight", ev2 -> p("prop " + ev2.getPropertyName() + " " + ev2.getOldValue() + "->" + ev2.getNewValue()));
        t.setRowHeight(20); t.putClientProperty("k", "v"); p("cp " + t.getClientProperty("k"));
        DefaultListSelectionModel sm = new DefaultListSelectionModel();
        sm.addListSelectionListener(le -> p("lsm " + le.getFirstIndex() + "-" + le.getLastIndex() + " " + le.getValueIsAdjusting()));
        sm.setSelectionInterval(2, 4); sm.addSelectionInterval(7, 8); sm.removeSelectionInterval(3, 3); sm.setValueIsAdjusting(true); sm.setSelectionInterval(0, 1); sm.setValueIsAdjusting(false);
        sm.insertIndexInterval(1, 2, true); p("min=" + sm.getMinSelectionIndex() + " max=" + sm.getMaxSelectionIndex() + " " + sm.isSelectedIndex(3) + " anchor=" + sm.getAnchorSelectionIndex() + " lead=" + sm.getLeadSelectionIndex());
        DefaultListModel<String> lm = new DefaultListModel<>();
        lm.addListDataListener(new ListDataListener() {
            public void intervalAdded(ListDataEvent x) { p("added " + x); } public void intervalRemoved(ListDataEvent x) { p("removed " + x); } public void contentsChanged(ListDataEvent x) { p("changed " + x); }
        });
        lm.addElement("a"); lm.add(0, "b"); lm.set(1, "c"); lm.removeRange(0, 1); lm.addAll(Arrays.asList("x", "y")); lm.removeAllElements(); lm.setSize(2);
        JList<String> jl = new JList<>(new String[] { "u", "v", "w", "x" });
        jl.addListSelectionListener(le -> p("jl " + le.getFirstIndex() + "-" + le.getLastIndex() + " adj=" + le.getValueIsAdjusting() + " src=" + (le.getSource() == jl)));
        jl.setSelectedIndex(2); jl.setSelectionInterval(0, 1); p(jl.getSelectedValuesList() + " " + jl.getSelectedIndex() + " " + Arrays.toString(jl.getSelectedIndices()));
        jl.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION); jl.addSelectionInterval(3, 3); p(jl.getSelectedValuesList().toString());
    }
}
