public class Test41_LitteralClasseEnum {
    enum Kind { Boolean, Byte; static boolean isBox(Class<?> c) { return c == Boolean.class || c == Byte.class; } }
    public static void main(String[] args) { System.out.println(Kind.isBox(java.lang.Boolean.class) + " " + Kind.isBox(String.class)); }
}
