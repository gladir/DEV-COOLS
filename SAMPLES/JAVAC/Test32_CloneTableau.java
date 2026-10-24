public class Test32_CloneTableau {
    static byte[] f(byte[] a) { return a.clone(); }
    Test32_CloneTableau(byte[] a) { byte[] b = a.clone(); }
    public static void main(String[] args) { byte[] x = f(new byte[2]); int[][] m = new int[2][2]; int[][] c = m.clone(); }
}
