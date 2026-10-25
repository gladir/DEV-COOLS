package javax.swing;
public class JPasswordField extends JTextField {
    private char echo = '*';
    public JPasswordField() { super(); }
    public JPasswordField(int columns) { super(columns); }
    public JPasswordField(String text, int columns) { super(text, columns); }
    public char[] getPassword() { return getText().toCharArray(); }
    public void setEchoChar(char c) { echo = c; }
    protected String shown() { return String.valueOf(echo).repeat(getText().length()); }
}
