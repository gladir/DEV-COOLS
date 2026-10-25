package javax.swing.text;
public interface Position {
    int getOffset();
    public static final class Bias {
        public static final Bias Forward = new Bias("Forward");
        public static final Bias Backward = new Bias("Backward");
        public String toString() { return name; }
        private Bias(String name) { this.name = name; }
        private String name;
    }
}
