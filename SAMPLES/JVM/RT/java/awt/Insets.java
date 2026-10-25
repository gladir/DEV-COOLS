package java.awt;
public class Insets implements Cloneable, java.io.Serializable {
    public int top, left, bottom, right;
    public Insets(int top, int left, int bottom, int right) { this.top = top; this.left = left; this.bottom = bottom; this.right = right; }
    public void set(int top, int left, int bottom, int right) { this.top = top; this.left = left; this.bottom = bottom; this.right = right; }
    public boolean equals(Object obj) { return obj instanceof Insets i && i.top == top && i.left == left && i.bottom == bottom && i.right == right; }
    public int hashCode() { int sum1 = left + bottom; int sum2 = right + top; int val1 = sum1 * (sum1 + 1) / 2 + left; int val2 = sum2 * (sum2 + 1) / 2 + top; int sum3 = val1 + val2; return sum3 * (sum3 + 1) / 2 + val2; }
    public Object clone() { return new Insets(top, left, bottom, right); }
    public String toString() { return getClass().getName() + "[top=" + top + ",left=" + left + ",bottom=" + bottom + ",right=" + right + "]"; }
}
