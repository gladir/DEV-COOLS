package java.awt.event;
public interface KeyListener extends java.util.EventListener {
    void keyTyped(KeyEvent e);
    void keyPressed(KeyEvent e);
    void keyReleased(KeyEvent e);
}
