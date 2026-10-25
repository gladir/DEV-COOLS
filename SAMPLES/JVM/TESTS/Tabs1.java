import javax.swing.*;
import javax.swing.event.*;
import java.awt.*;
import java.util.*;
public class Tabs1 {
    static void p(String s) { System.out.println(s); }
    static JPanel box(int w, int h, int mw, int mh) { JPanel x = new JPanel(); x.setPreferredSize(new Dimension(w, h)); x.setMinimumSize(new Dimension(mw, mh)); return x; }
    public static void main(String[] a) {
        JTabbedPane t = new JTabbedPane();
        t.addChangeListener(e -> p("change sel=" + t.getSelectedIndex()));
        p("empty sel=" + t.getSelectedIndex() + " count=" + t.getTabCount() + " place=" + t.getTabPlacement() + " pol=" + t.getTabLayoutPolicy());
        JPanel p1 = box(100, 50, 10, 10), p2 = box(80, 90, 10, 10), p3 = box(60, 30, 10, 10);
        p1.setName("n1");
        t.addTab("Un", p1); p("a1 sel=" + t.getSelectedIndex());
        t.addTab("Deux", null, p2, "tip2"); p("a2 sel=" + t.getSelectedIndex());
        t.insertTab("Zero", null, p3, null, 0); p("ins sel=" + t.getSelectedIndex() + " " + t.getTitleAt(0) + t.getTitleAt(1) + t.getTitleAt(2));
        t.setSelectedIndex(2); p("idx " + t.indexOfTab("Un") + t.indexOfComponent(p2) + t.indexOfTab("zz") + " " + t.getToolTipTextAt(2) + " " + (t.getSelectedComponent() == p2));
        t.setEnabledAt(1, false); p("en " + t.isEnabledAt(1) + t.isEnabledAt(0));
        t.removeTabAt(0); p("rm0 sel=" + t.getSelectedIndex() + " n=" + t.getTabCount() + " comps=" + t.getComponentCount());
        t.remove(p2); p("rm p2 sel=" + t.getSelectedIndex() + " n=" + t.getTabCount());
        t.add(p1.getName() == null ? "x" : "y", box(1, 1, 1, 1)); p("add n=" + t.getTabCount() + " sel=" + t.getSelectedIndex() + " " + t.getTitleAt(1));
        t.add(new JLabel("lab") {{ setName("nom"); }}); p("add2 " + t.getTitleAt(2));
        try { t.setSelectedIndex(9); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        try { t.getTitleAt(-1); } catch (Exception e) { p(e.getClass().getSimpleName() + ": " + e.getMessage()); }
        t.setSelectedIndex(-1); p("sel -1 " + t.getSelectedIndex() + " " + t.getSelectedComponent());
        t.removeAll(); p("all " + t.getTabCount() + " " + t.getComponentCount());
        // JSplitPane
        JPanel l = box(100, 40, 20, 10), r = box(60, 50, 30, 10);
        JSplitPane s = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, l, r);
        s.addPropertyChangeListener(JSplitPane.DIVIDER_LOCATION_PROPERTY, e -> p("prop loc " + e.getOldValue() + "->" + e.getNewValue()));
        s.addPropertyChangeListener(JSplitPane.LAST_DIVIDER_LOCATION_PROPERTY, e -> p("prop last " + e.getOldValue() + "->" + e.getNewValue()));
        p("split o=" + s.getOrientation() + " l=" + (s.getLeftComponent() == l) + " r=" + (s.getRightComponent() == r) + " ds=" + s.getDividerSize() + " loc=" + s.getDividerLocation() + " rw=" + s.getResizeWeight() + " cont=" + s.isContinuousLayout() + " one=" + s.isOneTouchExpandable());
        s.setSize(300, 100); s.doLayout();
        p("lay loc=" + s.getDividerLocation() + " l=" + l.getBounds() + " r=" + r.getBounds() + " pref=" + s.getPreferredSize() + " min=" + s.getMinimumSize());
        s.setDividerLocation(150); p("150 l=" + l.getBounds() + " r=" + r.getBounds() + " last=" + s.getLastDividerLocation());
        s.setSize(400, 100); s.doLayout(); p("grow0 loc=" + s.getDividerLocation() + " r=" + r.getBounds());
                s.setSize(450, 100); s.doLayout();
        s.setDividerLocation(0.25); p("prop loc=" + s.getDividerLocation() + " max=" + s.getMaximumDividerLocation() + " min=" + s.getMinimumDividerLocation());
        s.setOrientation(JSplitPane.VERTICAL_SPLIT); s.setSize(200, 300); s.doLayout(); p("vert loc=" + s.getDividerLocation() + " l=" + l.getBounds() + " r=" + r.getBounds());
        s.setTopComponent(null); p("top null " + s.getLeftComponent());
        JSplitPane d = new JSplitPane(); p("default " + d.getLeftComponent().getClass().getSimpleName() + " " + d.getRightComponent().getClass().getSimpleName());
        // JScrollBar / BoundedRangeModel
        JScrollBar sb = new JScrollBar(JScrollBar.VERTICAL, 10, 20, 0, 100);
        sb.addAdjustmentListener(e -> p("adj " + e.getValue() + " type=" + e.getAdjustmentType() + " adj=" + e.getValueIsAdjusting()));
        sb.setValue(95); p("sb " + sb.getValue() + " " + sb.getVisibleAmount() + " " + sb.getMaximum());
        sb.setValues(5, 10, 0, 50); sb.setVisibleAmount(100); p("sb2 " + sb.getValue() + " " + sb.getVisibleAmount());
        DefaultBoundedRangeModel bm = new DefaultBoundedRangeModel(5, 10, 0, 100);
        bm.setMaximum(8); p("bm " + bm); bm.setMinimum(20); p("bm " + bm);
        JViewport vp = new JViewport(); vp.setSize(100, 50); JPanel big = box(300, 200, 1, 1); vp.setView(big); vp.doLayout();
        p("vp view=" + big.getBounds() + " pos=" + vp.getViewPosition() + " rect=" + vp.getViewRect());
        vp.setViewPosition(new Point(500, 500)); p("vp pos=" + vp.getViewPosition() + " " + big.getLocation());
        vp.scrollRectToVisible(new Rectangle(10, 10, 5, 5)); p("vp pos=" + vp.getViewPosition());
        vp.scrollRectToVisible(new Rectangle(250, 120, 20, 20)); p("vp pos=" + vp.getViewPosition());
        EventListenerListTest();
    }
    static void EventListenerListTest() {
        EventListenerList l = new EventListenerList();
        ChangeListener c1 = e -> {}, c2 = e -> {};
        l.add(ChangeListener.class, c1); l.add(ChangeListener.class, c2); l.add(ListSelectionListener.class, e -> {});
        p("ell " + l.getListenerCount() + " " + l.getListenerCount(ChangeListener.class) + " " + (l.getListeners(ChangeListener.class)[0] == c2));
        l.remove(ChangeListener.class, c2); p("ell " + l.getListenerList().length);
        java.beans.PropertyChangeSupport s = new java.beans.PropertyChangeSupport("src");
        s.addPropertyChangeListener(e -> p("pcs all " + e.getPropertyName() + e.getOldValue() + e.getNewValue()));
        s.addPropertyChangeListener("x", e -> p("pcs x " + e.getNewValue()));
        s.firePropertyChange("x", 1, 2); s.firePropertyChange("y", 1, 1); s.firePropertyChange("y", false, true); s.firePropertyChange("z", null, "v");
        p("has " + s.hasListeners("x") + s.hasListeners("q") + " " + s.getPropertyChangeListeners().length);
    }
}
