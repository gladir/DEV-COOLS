package java.util.regex;
import java.lang.IllegalArgumentException;
public class PatternSyntaxException extends IllegalArgumentException {
    private static final long serialVersionUID = -3864639126226059218L;
    public PatternSyntaxException(String desc, String regex, int index) { super(desc + (index >= 0 ? " near index " + index : "") + "\n" + regex); }
}
