package java.awt;
public class Dialog extends Window {
    public Dialog(Frame owner) { this(owner, "", false); }
    public Dialog(Frame owner, String title) { this(owner, title, false); }
    public Dialog(Frame owner, boolean modal) { this(owner, "", modal); }
    public Dialog(Frame owner, String title, boolean modal) { super(owner); this.title = title; this.modal = modal; }
    public Dialog(Window owner, String title, boolean modal) { super(owner); this.title = title; this.modal = modal; }
    public Dialog(Window owner) { super(owner); }
    public enum ModalityType { MODELESS, DOCUMENT_MODAL, APPLICATION_MODAL, TOOLKIT_MODAL }
    public boolean isModal() { return modal; }
    public void setModal(boolean m) { modal = m; }
    public void setResizable(boolean b) { }
}
