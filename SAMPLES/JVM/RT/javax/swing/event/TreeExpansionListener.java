package javax.swing.event;
public interface TreeExpansionListener extends java.util.EventListener {
    void treeExpanded(TreeExpansionEvent event);
    void treeCollapsed(TreeExpansionEvent event);
}
