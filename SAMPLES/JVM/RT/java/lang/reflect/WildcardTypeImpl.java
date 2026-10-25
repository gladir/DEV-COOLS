package java.lang.reflect;
import java.util.Arrays;
final class WildcardTypeImpl implements WildcardType {
    private final Type[] upper, lower;
    WildcardTypeImpl(Type[] upper, Type[] lower) { this.upper = upper; this.lower = lower; }
    public Type[] getUpperBounds() { return upper.clone(); }
    public Type[] getLowerBounds() { return lower.clone(); }
    public String toString() {
        Type[] bounds = lower;
        StringBuilder sb = new StringBuilder();
        if (lower.length > 0) sb.append("? super ");
        else {
            if (upper.length > 0 && !upper[0].equals(Object.class)) { bounds = upper; sb.append("? extends "); }
            else return "?";
        }
        for (int i = 0; i < bounds.length; i++) {
            if (i > 0) sb.append(" & ");
            sb.append(bounds[i].getTypeName());
        }
        return sb.toString();
    }
    public boolean equals(Object o) {
        if (o instanceof WildcardType) {
            WildcardType that = (WildcardType) o;
            return Arrays.equals(lower, that.getLowerBounds()) && Arrays.equals(upper, that.getUpperBounds());
        }
        return false;
    }
    public int hashCode() { return Arrays.hashCode(lower) ^ Arrays.hashCode(upper); }
}
