package java.text;
import java.util.Comparator;
import java.util.Locale;
public class Collator implements Comparator<Object>, Cloneable {
    public static final int PRIMARY = 0, SECONDARY = 1, TERTIARY = 2, IDENTICAL = 3;
    public static final int NO_DECOMPOSITION = 0, CANONICAL_DECOMPOSITION = 1, FULL_DECOMPOSITION = 2;
    private int strength = TERTIARY;
    private int decomposition = NO_DECOMPOSITION;
    protected Collator() { }
    public static Collator getInstance() { return new Collator(); }
    public static Collator getInstance(Locale l) { return new Collator(); }
    public int getStrength() { return strength; }
    public void setStrength(int s) {
        if (s != PRIMARY && s != SECONDARY && s != TERTIARY && s != IDENTICAL) throw new IllegalArgumentException("Incorrect comparison level.");
        strength = s;
    }
    public int getDecomposition() { return decomposition; }
    public void setDecomposition(int d) { decomposition = d; }
    private static final String ACC_FROM = "àáâãäåçèéêëìíîïñòóôõöùúûüýÿ";
    private static final String ACC_TO = "aaaaaaceeeeiiiinooooouuuuyy";
    private static char base(char c) {
        char l = Character.toLowerCase(c);
        int i = ACC_FROM.indexOf(l);
        return i >= 0 ? ACC_TO.charAt(i) : l;
    }
    private static int weight(char c) {
        char b = base(c);
        if (Character.isLetter(b)) return 2000 + b;
        if (Character.isDigit(b)) return 1000 + b;
        return b;
    }
    public int compare(String source, String target) {
        int n = Math.min(source.length(), target.length());
        for (int i = 0; i < n; i++) {
            int a = weight(source.charAt(i)), b = weight(target.charAt(i));
            if (a != b) return a < b ? -1 : 1;
        }
        if (source.length() != target.length()) return source.length() < target.length() ? -1 : 1;
        if (strength >= SECONDARY) {
            for (int i = 0; i < n; i++) {
                char x = Character.toLowerCase(source.charAt(i)), y = Character.toLowerCase(target.charAt(i));
                if (x != y) return x < y ? -1 : 1;
            }
        }
        if (strength >= TERTIARY) {
            for (int i = 0; i < n; i++) {
                char x = source.charAt(i), y = target.charAt(i);
                if (x != y) return Character.isLowerCase(x) ? -1 : 1;
            }
        }
        return 0;
    }
    public int compare(Object o1, Object o2) { return compare((String) o1, (String) o2); }
    public boolean equals(String source, String target) { return compare(source, target) == 0; }
    public Object clone() { try { return super.clone(); } catch (CloneNotSupportedException e) { throw new InternalError(e.toString()); } }
    public int hashCode() { return strength; }
}
