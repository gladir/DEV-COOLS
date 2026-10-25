package java.awt.event;
import java.awt.*;
public class KeyEvent extends InputEvent {
    public static final int KEY_FIRST = 400, KEY_TYPED = 400, KEY_PRESSED = 401, KEY_RELEASED = 402;
    public static final char CHAR_UNDEFINED = '￿';
    public static final int VK_ENTER = '\n', VK_BACK_SPACE = '\b', VK_TAB = '\t', VK_CANCEL = 0x03, VK_CLEAR = 0x0C, VK_SHIFT = 0x10, VK_CONTROL = 0x11, VK_ALT = 0x12;
    public static final int VK_PAUSE = 0x13, VK_CAPS_LOCK = 0x14, VK_ESCAPE = 0x1B, VK_SPACE = 0x20, VK_PAGE_UP = 0x21, VK_PAGE_DOWN = 0x22, VK_END = 0x23, VK_HOME = 0x24;
    public static final int VK_LEFT = 0x25, VK_UP = 0x26, VK_RIGHT = 0x27, VK_DOWN = 0x28, VK_COMMA = 0x2C, VK_MINUS = 0x2D, VK_PERIOD = 0x2E, VK_SLASH = 0x2F;
    public static final int VK_0 = 0x30, VK_1 = 0x31, VK_2 = 0x32, VK_3 = 0x33, VK_4 = 0x34, VK_5 = 0x35, VK_6 = 0x36, VK_7 = 0x37, VK_8 = 0x38, VK_9 = 0x39;
    public static final int VK_SEMICOLON = 0x3B, VK_EQUALS = 0x3D;
    public static final int VK_A = 0x41, VK_B = 0x42, VK_C = 0x43, VK_D = 0x44, VK_E = 0x45, VK_F = 0x46, VK_G = 0x47, VK_H = 0x48, VK_I = 0x49, VK_J = 0x4A, VK_K = 0x4B, VK_L = 0x4C, VK_M = 0x4D;
    public static final int VK_N = 0x4E, VK_O = 0x4F, VK_P = 0x50, VK_Q = 0x51, VK_R = 0x52, VK_S = 0x53, VK_T = 0x54, VK_U = 0x55, VK_V = 0x56, VK_W = 0x57, VK_X = 0x58, VK_Y = 0x59, VK_Z = 0x5A;
    public static final int VK_NUMPAD0 = 0x60, VK_NUMPAD1 = 0x61, VK_NUMPAD2 = 0x62, VK_NUMPAD3 = 0x63, VK_NUMPAD4 = 0x64, VK_NUMPAD5 = 0x65, VK_NUMPAD6 = 0x66, VK_NUMPAD7 = 0x67, VK_NUMPAD8 = 0x68, VK_NUMPAD9 = 0x69;
    public static final int VK_MULTIPLY = 0x6A, VK_ADD = 0x6B, VK_SUBTRACT = 0x6D, VK_DECIMAL = 0x6E, VK_DIVIDE = 0x6F, VK_DELETE = 0x7F, VK_INSERT = 0x9B;
    public static final int VK_F1 = 0x70, VK_F2 = 0x71, VK_F3 = 0x72, VK_F4 = 0x73, VK_F5 = 0x74, VK_F6 = 0x75, VK_F7 = 0x76, VK_F8 = 0x77, VK_F9 = 0x78, VK_F10 = 0x79, VK_F11 = 0x7A, VK_F12 = 0x7B;
    public static final int VK_UNDEFINED = 0x0;
    int keyCode;
    char keyChar;
    public KeyEvent(Component source, int id, long when, int modifiers, int keyCode, char keyChar) {
        super(source, id, when, modifiers); this.keyCode = keyCode; this.keyChar = keyChar;
    }
    public KeyEvent(Component source, int id, long when, int modifiers, int keyCode) { this(source, id, when, modifiers, keyCode, CHAR_UNDEFINED); }
    public int getKeyCode() { return keyCode; }
    public char getKeyChar() { return keyChar; }
    public void setKeyChar(char c) { keyChar = c; }
    public static String getKeyText(int keyCode) {
        if (keyCode >= VK_A && keyCode <= VK_Z || keyCode >= VK_0 && keyCode <= VK_9) return String.valueOf((char) keyCode);
        switch (keyCode) { case VK_ENTER: return "Enter"; case VK_SPACE: return "Space"; case VK_ESCAPE: return "Escape"; case VK_LEFT: return "Left"; case VK_RIGHT: return "Right"; case VK_UP: return "Up"; case VK_DOWN: return "Down"; case VK_BACK_SPACE: return "Backspace"; case VK_TAB: return "Tab"; case VK_DELETE: return "Delete"; }
        return "Unknown keyCode: 0x" + Integer.toHexString(keyCode);
    }
    public static boolean isActionKey(int c) { return c >= VK_PAGE_UP && c <= VK_DOWN || c >= VK_F1 && c <= VK_F12; }
    public String paramString() { return (id == KEY_PRESSED ? "KEY_PRESSED" : id == KEY_RELEASED ? "KEY_RELEASED" : "KEY_TYPED") + ",keyCode=" + keyCode + ",keyChar='" + keyChar + "'"; }
}
