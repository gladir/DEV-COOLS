package java.io;
public class DataInputStream extends FilterInputStream implements DataInput {
    public DataInputStream(InputStream in) { super(in); }
    private byte[] readBuffer = new byte[8];
    public final int read(byte[] b) throws IOException { return in.read(b, 0, b.length); }
    public final int read(byte[] b, int off, int len) throws IOException { return in.read(b, off, len); }
    public final void readFully(byte[] b) throws IOException { readFully(b, 0, b.length); }
    public final void readFully(byte[] b, int off, int len) throws IOException {
        if (len < 0) throw new IndexOutOfBoundsException();
        int n = 0;
        while (n < len) {
            int count = in.read(b, off + n, len - n);
            if (count < 0) throw new EOFException();
            n += count;
        }
    }
    public final int skipBytes(int n) throws IOException {
        int total = 0;
        int cur = 0;
        while ((total < n) && ((cur = (int) in.skip(n - total)) > 0)) total += cur;
        return total;
    }
    public final boolean readBoolean() throws IOException {
        int ch = in.read();
        if (ch < 0) throw new EOFException();
        return (ch != 0);
    }
    public final byte readByte() throws IOException {
        int ch = in.read();
        if (ch < 0) throw new EOFException();
        return (byte) (ch);
    }
    public final int readUnsignedByte() throws IOException {
        int ch = in.read();
        if (ch < 0) throw new EOFException();
        return ch;
    }
    public final short readShort() throws IOException {
        int ch1 = in.read(), ch2 = in.read();
        if ((ch1 | ch2) < 0) throw new EOFException();
        return (short) ((ch1 << 8) + (ch2 << 0));
    }
    public final int readUnsignedShort() throws IOException {
        int ch1 = in.read(), ch2 = in.read();
        if ((ch1 | ch2) < 0) throw new EOFException();
        return (ch1 << 8) + (ch2 << 0);
    }
    public final char readChar() throws IOException {
        int ch1 = in.read(), ch2 = in.read();
        if ((ch1 | ch2) < 0) throw new EOFException();
        return (char) ((ch1 << 8) + (ch2 << 0));
    }
    public final int readInt() throws IOException {
        int ch1 = in.read(), ch2 = in.read(), ch3 = in.read(), ch4 = in.read();
        if ((ch1 | ch2 | ch3 | ch4) < 0) throw new EOFException();
        return ((ch1 << 24) + (ch2 << 16) + (ch3 << 8) + (ch4 << 0));
    }
    public final long readLong() throws IOException {
        readFully(readBuffer, 0, 8);
        return (((long) readBuffer[0] << 56) + ((long) (readBuffer[1] & 255) << 48) + ((long) (readBuffer[2] & 255) << 40)
            + ((long) (readBuffer[3] & 255) << 32) + ((long) (readBuffer[4] & 255) << 24) + ((readBuffer[5] & 255) << 16)
            + ((readBuffer[6] & 255) << 8) + ((readBuffer[7] & 255) << 0));
    }
    public final float readFloat() throws IOException { return Float.intBitsToFloat(readInt()); }
    public final double readDouble() throws IOException { return Double.longBitsToDouble(readLong()); }
    @Deprecated
    public final String readLine() throws IOException {
        StringBuilder sb = new StringBuilder();
        int c = in.read();
        if (c < 0) return null;
        while (c >= 0 && c != '\n') {
            if (c == '\r') {
                if (in.markSupported()) {
                    in.mark(1);
                    int d = in.read();
                    if (d != '\n' && d >= 0) in.reset();
                }
                break;
            }
            sb.append((char) c);
            c = in.read();
        }
        return sb.toString();
    }
    public final String readUTF() throws IOException { return readUTF(this); }
    public static final String readUTF(DataInput in) throws IOException {
        int utflen = in.readUnsignedShort();
        byte[] bytearr = new byte[utflen];
        char[] chararr = new char[utflen];
        int c, char2, char3;
        int count = 0;
        int chararr_count = 0;
        in.readFully(bytearr, 0, utflen);
        while (count < utflen) {
            c = (int) bytearr[count] & 0xff;
            if (c > 127) break;
            count++;
            chararr[chararr_count++] = (char) c;
        }
        while (count < utflen) {
            c = (int) bytearr[count] & 0xff;
            switch (c >> 4) {
                case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7:
                    count++;
                    chararr[chararr_count++] = (char) c;
                    break;
                case 12: case 13:
                    count += 2;
                    if (count > utflen) throw new UTFDataFormatException("malformed input: partial character at end");
                    char2 = (int) bytearr[count - 1];
                    if ((char2 & 0xC0) != 0x80) throw new UTFDataFormatException("malformed input around byte " + count);
                    chararr[chararr_count++] = (char) (((c & 0x1F) << 6) | (char2 & 0x3F));
                    break;
                case 14:
                    count += 3;
                    if (count > utflen) throw new UTFDataFormatException("malformed input: partial character at end");
                    char2 = (int) bytearr[count - 2];
                    char3 = (int) bytearr[count - 1];
                    if (((char2 & 0xC0) != 0x80) || ((char3 & 0xC0) != 0x80)) throw new UTFDataFormatException("malformed input around byte " + (count - 1));
                    chararr[chararr_count++] = (char) (((c & 0x0F) << 12) | ((char2 & 0x3F) << 6) | ((char3 & 0x3F) << 0));
                    break;
                default:
                    throw new UTFDataFormatException("malformed input around byte " + count);
            }
        }
        return new String(chararr, 0, chararr_count);
    }
}
