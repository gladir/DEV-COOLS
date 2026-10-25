package javax.swing;
import java.awt.Component;
import java.awt.event.*;
import java.util.EventObject;
import javax.swing.table.*;
public class DefaultCellEditor extends AbstractCellEditor implements TableCellEditor {
    protected JComponent editorComponent;
    protected EditorDelegate delegate;
    protected int clickCountToStart = 1;
    public DefaultCellEditor(final JTextField textField) {
        editorComponent = textField;
        this.clickCountToStart = 2;
        delegate = new EditorDelegate() {
            public void setValue(Object value) { textField.setText((value != null) ? value.toString() : ""); }
            public Object getCellEditorValue() { return textField.getText(); }
        };
        textField.addActionListener(delegate);
    }
    public DefaultCellEditor(final JCheckBox checkBox) {
        editorComponent = checkBox;
        delegate = new EditorDelegate() {
            public void setValue(Object value) {
                boolean selected = false;
                if (value instanceof Boolean) selected = ((Boolean) value).booleanValue();
                else if (value instanceof String) selected = value.equals("true");
                checkBox.setSelected(selected);
            }
            public Object getCellEditorValue() { return Boolean.valueOf(checkBox.isSelected()); }
        };
        checkBox.addActionListener(delegate);
    }
    public DefaultCellEditor(final JComboBox<?> comboBox) {
        editorComponent = comboBox;
        delegate = new EditorDelegate() {
            public void setValue(Object value) { comboBox.setSelectedItem(value); }
            public Object getCellEditorValue() { return comboBox.getSelectedItem(); }
            public boolean shouldSelectCell(EventObject anEvent) {
                if (anEvent instanceof MouseEvent) { MouseEvent e = (MouseEvent) anEvent; return e.getID() != MouseEvent.MOUSE_DRAGGED; }
                return true;
            }
        };
        comboBox.addActionListener(delegate);
    }
    public Component getComponent() { return editorComponent; }
    public void setClickCountToStart(int count) { clickCountToStart = count; }
    public int getClickCountToStart() { return clickCountToStart; }
    public Object getCellEditorValue() { return delegate.getCellEditorValue(); }
    public boolean isCellEditable(EventObject anEvent) { return delegate.isCellEditable(anEvent); }
    public boolean shouldSelectCell(EventObject anEvent) { return delegate.shouldSelectCell(anEvent); }
    public boolean stopCellEditing() { return delegate.stopCellEditing(); }
    public void cancelCellEditing() { delegate.cancelCellEditing(); }
    public Component getTableCellEditorComponent(JTable table, Object value, boolean isSelected, int row, int column) {
        delegate.setValue(value);
        return editorComponent;
    }
    protected class EditorDelegate implements ActionListener, ItemListener, java.io.Serializable {
        protected Object value;
        public Object getCellEditorValue() { return value; }
        public void setValue(Object value) { this.value = value; }
        public boolean isCellEditable(EventObject anEvent) {
            if (anEvent instanceof MouseEvent) return ((MouseEvent) anEvent).getClickCount() >= clickCountToStart;
            return true;
        }
        public boolean shouldSelectCell(EventObject anEvent) { return true; }
        public boolean startCellEditing(EventObject anEvent) { return true; }
        public boolean stopCellEditing() { fireEditingStopped(); return true; }
        public void cancelCellEditing() { fireEditingCanceled(); }
        public void actionPerformed(ActionEvent e) { DefaultCellEditor.this.stopCellEditing(); }
        public void itemStateChanged(ItemEvent e) { DefaultCellEditor.this.stopCellEditing(); }
    }
}
