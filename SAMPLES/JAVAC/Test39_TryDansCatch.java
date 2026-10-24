import java.io.*;
public class Test39_TryDansCatch {
    static class MyEx extends Exception {}
    static void stop() throws MyEx {}
    static void f(OutputStream inTarget, InputStream in) throws IOException {
        new OutputStream() {
            public void write(int b) throws IOException {
                try {
                    int r = in.read();
                    inTarget.write(r);
                } catch (InterruptedIOException exc) {
                    try { stop(); } catch (MyEx ex) { System.out.println("x"); }
                } catch (IOException exc) {
                    inTarget.write(2);
                }
            }
        }.write(1);
    }
    public static void main(String[] args) throws Exception { f(new ByteArrayOutputStream(), new ByteArrayInputStream(new byte[]{5})); System.out.println("ok"); }
}
