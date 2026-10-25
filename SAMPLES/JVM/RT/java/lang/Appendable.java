package java.lang;
public interface Appendable {
    Appendable append(CharSequence csq) throws java.io.IOException;
    Appendable append(CharSequence csq, int start, int end) throws java.io.IOException;
    Appendable append(char c) throws java.io.IOException;
}
