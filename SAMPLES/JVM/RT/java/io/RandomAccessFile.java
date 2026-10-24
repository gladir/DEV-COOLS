package java.io;
public class RandomAccessFile implements DataOutput, DataInput, Closeable {
    private int h = -1;
    private final boolean rw;
    private final String path;
    public RandomAccessFile(String name, String mode) throws FileNotFoundException {
        if (!mode.equals("r") && !mode.equals("rw") && !mode.equals("rws") && !mode.equals("rwd"))
            throw new IllegalArgumentException("Illegal mode \"" + mode + "\" must be one of \"r\", \"rw\", \"rws\", or \"rwd\"");
        rw = !mode.equals("r");
        path = name;
        if (FS.isDir(name)) throw new FileNotFoundException(name + " (Is a directory)");
        h = FS.open(name, rw ? 3 : 0);
        if (h < 0) throw new FileNotFoundException(name + (rw ? " (No such file or directory)" : " (No such file or directory)"));
    }
    public RandomAccessFile(File file, String mode) throws FileNotFoundException { this(file.getPath(), mode); }
    private void chk() throws IOException { if (h < 0) throw new IOException("Stream Closed"); }
    public int read() throws IOException { chk(); return FS.read(h); }
    public int read(byte[] b, int off, int len) throws IOException {
        chk();
        if (len == 0) return 0;
        return FS.readBytes(h, b, off, len);
    }
    public int read(byte[] b) throws IOException { return read(b, 0, b.length); }
    public final void readFully(byte[] b) throws IOException { readFully(b, 0, b.length); }
    public final void readFully(byte[] b, int off, int len) throws IOException {
        int n = 0;
        do {
            int count = this.read(b, off + n, len - n);
            if (count < 0) throw new EOFException();
            n += count;
        } while (n < len);
    }
    public int skipBytes(int n) throws IOException {
        if (n <= 0) return 0;
        long pos = getFilePointer();
        long len = length();
        long newpos = pos + n;
        if (newpos > len) newpos = len;
        seek(newpos);
        return (int) (newpos - pos);
    }
    public void write(int b) throws IOException { chk(); if (!rw) throw new IOException("Bad file descriptor"); FS.write(h, new byte[]{(byte) b}, 0, 1); }
    public void write(byte[] b) throws IOException { write(b, 0, b.length); }
    public void write(byte[] b, int off, int len) throws IOException { chk(); if (!rw) throw new IOException("Bad file descriptor"); FS.write(h, b, off, len); }
    public long getFilePointer() throws IOException { chk(); return FS.pos(h); }
    public void seek(long pos) throws IOException {
        if (pos < 0) throw new IOException("Negative seek offset");
        chk();
        FS.seek(h, pos);
    }
    public long length() throws IOException { chk(); return FS.size(h); }
    public void setLength(long newLength) throws IOException {
        chk();
        long p = FS.pos(h);
        FS.setLength(h, newLength);
        if (p > newLength) FS.seek(h, newLength);
    }
    public void close() throws IOException { if (h >= 0) { FS.close(h); h = -1; } }
    public final boolean readBoolean() throws IOException { int ch = this.read(); if (ch < 0) throw new EOFException(); return (ch != 0); }
    public final byte readByte() throws IOException { int ch = this.read(); if (ch < 0) throw new EOFException(); return (byte) (ch); }
    public final int readUnsignedByte() throws IOException { int ch = this.read(); if (ch < 0) throw new EOFException(); return ch; }
    public final short readShort() throws IOException { int ch1 = this.read(), ch2 = this.read(); if ((ch1 | ch2) < 0) throw new EOFException(); return (short) ((ch1 << 8) + ch2); }
    public final int readUnsignedShort() throws IOException { int ch1 = this.read(), ch2 = this.read(); if ((ch1 | ch2) < 0) throw new EOFException(); return (ch1 << 8) + ch2; }
    public final char readChar() throws IOException { int ch1 = this.read(), ch2 = this.read(); if ((ch1 | ch2) < 0) throw new EOFException(); return (char) ((ch1 << 8) + ch2); }
    public final int readInt() throws IOException {
        int ch1 = this.read(), ch2 = this.read(), ch3 = this.read(), ch4 = this.read();
        if ((ch1 | ch2 | ch3 | ch4) < 0) throw new EOFException();
        return ((ch1 << 24) + (ch2 << 16) + (ch3 << 8) + ch4);
    }
    public final long readLong() throws IOException { return ((long) (readInt()) << 32) + (readInt() & 0xFFFFFFFFL); }
    public final float readFloat() throws IOException { return Float.intBitsToFloat(readInt()); }
    public final double readDouble() throws IOException { return Double.longBitsToDouble(readLong()); }
    public final String readLine() throws IOException {
        StringBuilder input = new StringBuilder();
        int c = -1;
        boolean eol = false;
        while (!eol) {
            switch (c = read()) {
                case -1: case '\n': eol = true; break;
                case '\r':
                    eol = true;
                    long cur = getFilePointer();
                    if ((read()) != '\n') seek(cur);
                    break;
                default: input.append((char) c); break;
            }
        }
        if ((c == -1) && (input.length() == 0)) return null;
        return input.toString();
    }
    public final String readUTF() throws IOException { return DataInputStream.readUTF(this); }
    public final void writeBoolean(boolean v) throws IOException { write(v ? 1 : 0); }
    public final void writeByte(int v) throws IOException { write(v); }
    public final void writeShort(int v) throws IOException { write(new byte[]{(byte) (v >>> 8), (byte) v}); }
    public final void writeChar(int v) throws IOException { writeShort(v); }
    public final void writeInt(int v) throws IOException { write(new byte[]{(byte) (v >>> 24), (byte) (v >>> 16), (byte) (v >>> 8), (byte) v}); }
    public final void writeLong(long v) throws IOException { writeInt((int) (v >>> 32)); writeInt((int) v); }
    public final void writeFloat(float v) throws IOException { writeInt(Float.floatToIntBits(v)); }
    public final void writeDouble(double v) throws IOException { writeLong(Double.doubleToLongBits(v)); }
    public final void writeBytes(String s) throws IOException {
        byte[] b = new byte[s.length()];
        for (int i = 0; i < b.length; i++) b[i] = (byte) s.charAt(i);
        write(b, 0, b.length);
    }
    public final void writeChars(String s) throws IOException {
        byte[] b = new byte[s.length() * 2];
        for (int i = 0; i < s.length(); i++) { char c = s.charAt(i); b[2 * i] = (byte) (c >>> 8); b[2 * i + 1] = (byte) c; }
        write(b, 0, b.length);
    }
    public final void writeUTF(String str) throws IOException { DataOutputStream.writeUTF(str, this); }
}
