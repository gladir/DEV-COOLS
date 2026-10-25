import java.io.*;
import java.util.*;
public class Io1 {
    public static void main(String[] a) throws Exception {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (DataOutputStream d = new DataOutputStream(new BufferedOutputStream(bo))) {
            d.writeInt(-5); d.writeLong(1L << 40); d.writeDouble(3.25); d.writeFloat(1.5f); d.writeUTF("héllo\u0000€"); d.writeBoolean(true); d.writeChar('Z'); d.writeShort(-2); d.writeByte(200); d.writeBytes("ab"); d.writeChars("cd");
            System.out.println(d.size());
        }
        byte[] b = bo.toByteArray();
        System.out.println(b.length + " " + Arrays.toString(Arrays.copyOf(b, 12)));
        DataInputStream di = new DataInputStream(new ByteArrayInputStream(b));
        System.out.println(di.readInt() + " " + di.readLong() + " " + di.readDouble() + " " + di.readFloat() + " " + di.readUTF() + " " + di.readBoolean() + " " + di.readChar() + " " + di.readShort() + " " + di.readUnsignedByte());
        byte[] two = new byte[2]; di.readFully(two); System.out.println(new String(two) + di.available() + " " + di.skipBytes(100));
        try { di.readInt(); } catch (EOFException e) { System.out.println("EOF " + e.getMessage()); }
        File f = File.createTempFile("iox", ".bin");
        try (RandomAccessFile r = new RandomAccessFile(f, "rw")) {
            r.writeInt(1); r.writeInt(2); r.writeUTF("tail"); r.seek(4); System.out.println(r.readInt() + " " + r.readUTF() + " " + r.getFilePointer() + " " + r.length());
            r.seek(0); r.writeInt(99); r.seek(0); System.out.println(r.readInt()); r.setLength(4); System.out.println(r.length());
            r.seek(r.length()); r.write(new byte[]{1, 2, 3}); r.seek(2); System.out.println(r.read() + " " + r.read() + " " + r.read() + " " + r.read() + " " + r.read() + " " + r.read());
        }
        try (FileOutputStream fo = new FileOutputStream(f, true)) { fo.write("\nx y\n3.5 'q' word".getBytes()); }
        try (FileInputStream fi = new FileInputStream(f)) { System.out.println(fi.available() + " " + fi.skip(7) + " " + fi.read()); }
        try (BufferedInputStream bi = new BufferedInputStream(new FileInputStream(f))) {
            bi.mark(100); byte[] x = bi.readNBytes(3); bi.reset(); System.out.println(x.length + " " + bi.read() + " " + bi.markSupported() + " " + bi.available());
        }
        PushbackInputStream pb = new PushbackInputStream(new ByteArrayInputStream("abc".getBytes()), 2);
        int c1 = pb.read(); pb.unread(c1); pb.unread('z'); System.out.println((char) pb.read() + "" + (char) pb.read() + (char) pb.read());
        SequenceInputStream sq = new SequenceInputStream(new ByteArrayInputStream("12".getBytes()), new ByteArrayInputStream("34".getBytes()));
        System.out.println(new String(sq.readAllBytes()));
        StreamTokenizer st = new StreamTokenizer(new StringReader("x = 3.5 + foo(\"s t\") // c\n 'q' -7"));
        st.slashSlashComments(true);
        StringBuilder sb = new StringBuilder();
        while (st.nextToken() != StreamTokenizer.TT_EOF) sb.append(st.toString()).append(';');
        System.out.println(sb);
        LineNumberReader lr = new LineNumberReader(new StringReader("a\nb\r\nc"));
        while (lr.readLine() != null) System.out.print(lr.getLineNumber()); System.out.println();
        CharArrayWriter cw = new CharArrayWriter(); cw.write("hello"); cw.append('!'); System.out.println(cw + " " + cw.size());
        CharArrayReader cr = new CharArrayReader(cw.toCharArray()); cr.skip(2); System.out.println((char) cr.read());
        PushbackReader pr = new PushbackReader(new StringReader("xy")); int q = pr.read(); pr.unread(q); System.out.println((char) pr.read());
        PipedOutputStream po = new PipedOutputStream(); PipedInputStream pi = new PipedInputStream(po);
        Thread t = new Thread(() -> { try { for (int i = 0; i < 2000; i++) po.write(i % 251); po.close(); } catch (IOException e) { e.printStackTrace(); } });
        t.start(); long sum = 0; int cnt = 0, v; while ((v = pi.read()) != -1) { sum += v; cnt++; } t.join();
        System.out.println(cnt + " " + sum);
        InputStream nis = InputStream.nullInputStream(); System.out.println(nis.read());
        System.out.println(new ByteArrayInputStream("hello".getBytes()).transferTo(OutputStream.nullOutputStream()));
        f.delete();
    }
}
