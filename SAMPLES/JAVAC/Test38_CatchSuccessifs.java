import java.io.*;
public class Test38_CatchSuccessifs {
    static void f(OutputStream inTarget, InputStream in) throws IOException {
        try {
            int r = in.read();
            inTarget.write(new byte[] {1, (byte) r});
        } catch (InterruptedIOException exc) {
            System.out.println("intr");
        } catch (IOException exc) {
            inTarget.write(2);
        }
    }
    public static void main(String[] args) throws Exception { f(new ByteArrayOutputStream(), new ByteArrayInputStream(new byte[]{5})); System.out.println("ok"); }
}
