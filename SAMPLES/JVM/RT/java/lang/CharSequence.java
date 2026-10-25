package java.lang;
public interface CharSequence {
    int length();
    char charAt(int index);
    CharSequence subSequence(int start, int end);
    String toString();
    default boolean isEmpty() { return length() == 0; }
}
