package java.io;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
public class ObjectOutputStream extends OutputStream implements ObjectOutput, ObjectStreamConstants {
    private static final int BUFSIZE = 1024;
    private final OutputStream out;
    private final byte[] buf = new byte[BUFSIZE];
    private int pos;
    private boolean blkmode;
    private final byte[] hbuf = new byte[8];
    private Object[] hobjs = new Object[16];
    private int[] hids = new int[16];
    private int hcount, hnext;
    private Object curObj;
    private ObjectStreamClass curDesc;
    private PutFieldImpl curPut;
    private int depth;
    private boolean enableReplace;
    private int protocol = PROTOCOL_VERSION_2;
    private final boolean subclass;
    private IOException abortEx;

    public ObjectOutputStream(OutputStream out) throws IOException {
        this.out = out;
        this.subclass = false;
        writeShortRaw(STREAM_MAGIC);
        writeShortRaw(STREAM_VERSION);
        setBlockDataMode(true);
    }
    protected ObjectOutputStream() throws IOException, SecurityException { this.out = null; this.subclass = true; }
    public void useProtocolVersion(int version) throws IOException {
        if (hcount != 0) throw new IllegalStateException("stream non-empty");
        if (version != PROTOCOL_VERSION_1 && version != PROTOCOL_VERSION_2) throw new IllegalArgumentException("unknown version: " + version);
        protocol = version;
    }
    int getProtocolVersion() { return protocol; }
    public final void writeObject(Object obj) throws IOException {
        if (subclass) { writeObjectOverride(obj); return; }
        try {
            writeObject0(obj, false);
        } catch (IOException ex) {
            if (depth == 0) {
                try { writeFatalException(ex); } catch (IOException ex2) { }
            }
            throw ex;
        }
    }
    protected void writeObjectOverride(Object obj) throws IOException { }
    public void writeUnshared(Object obj) throws IOException {
        try { writeObject0(obj, true); }
        catch (IOException ex) {
            if (depth == 0) writeFatalException(ex);
            throw ex;
        }
    }
    public void defaultWriteObject() throws IOException {
        if (curObj == null || curDesc == null) throw new NotActiveException("not in call to writeObject");
        boolean old = setBlockDataMode(false);
        defaultWriteFields(curObj, curDesc);
        setBlockDataMode(old);
    }
    public PutField putFields() throws IOException {
        if (curPut == null) {
            if (curObj == null || curDesc == null) throw new NotActiveException("not in call to writeObject");
            curPut = new PutFieldImpl(curDesc);
        }
        return curPut;
    }
    public void writeFields() throws IOException {
        if (curPut == null) throw new NotActiveException("no current PutField object");
        boolean old = setBlockDataMode(false);
        curPut.writeFields();
        setBlockDataMode(old);
    }
    public void reset() throws IOException {
        if (depth != 0) throw new IOException("stream active");
        boolean old = setBlockDataMode(false);
        writeByteRaw(TC_RESET);
        clearHandles();
        setBlockDataMode(old);
    }
    protected void annotateClass(Class<?> cl) throws IOException { }
    protected void annotateProxyClass(Class<?> cl) throws IOException { }
    protected Object replaceObject(Object obj) throws IOException { return obj; }
    protected boolean enableReplaceObject(boolean enable) throws SecurityException {
        boolean old = enableReplace;
        enableReplace = enable;
        return old;
    }
    protected void writeStreamHeader() throws IOException {
        writeShortRaw(STREAM_MAGIC);
        writeShortRaw(STREAM_VERSION);
    }
    public void write(int val) throws IOException { writeRaw1(val); }
    public void write(byte[] buf) throws IOException { writeBytesRaw(buf, 0, buf.length); }
    public void write(byte[] buf, int off, int len) throws IOException {
        if (buf == null) throw new NullPointerException();
        int endoff = off + len;
        if (off < 0 || len < 0 || endoff > buf.length || endoff < 0) throw new IndexOutOfBoundsException();
        writeBytesRaw(buf, off, len);
    }
    public void flush() throws IOException { drain(); out.flush(); }
    protected void drain() throws IOException { writeBlockHeaderAndData(); }
    public void close() throws IOException {
        flush();
        clearHandles();
        out.close();
    }
    public void writeBoolean(boolean val) throws IOException { writeRaw1(val ? 1 : 0); }
    public void writeByte(int val) throws IOException { writeRaw1(val); }
    public void writeShort(int val) throws IOException { writeRaw2(val); }
    public void writeChar(int val) throws IOException { writeRaw2(val); }
    public void writeInt(int val) throws IOException { writeRaw4(val); }
    public void writeFloat(float val) throws IOException { writeRaw4(Float.floatToIntBits(val)); }
    public void writeLong(long val) throws IOException { writeRaw8(val); }
    public void writeDouble(double val) throws IOException { writeRaw8(Double.doubleToLongBits(val)); }
    public void writeBytes(String str) throws IOException {
        int len = str.length();
        for (int i = 0; i < len; i++) writeRaw1(str.charAt(i));
    }
    public void writeChars(String str) throws IOException {
        int len = str.length();
        for (int i = 0; i < len; i++) writeRaw2(str.charAt(i));
    }
    public void writeUTF(String str) throws IOException {
        int utflen = utfLen(str);
        if (utflen > 0xFFFF) throw new UTFDataFormatException();
        writeRaw2(utflen);
        writeUTFBody(str);
    }

    // ----- couche bas niveau avec blocs de donnees ----------------------------
    private void writeBlockHeaderAndData() throws IOException {
        if (blkmode && pos > 0) {
            if (pos <= 0xFF) { out.write(TC_BLOCKDATA); out.write(pos); }
            else {
                out.write(TC_BLOCKDATALONG);
                out.write(pos >>> 24); out.write(pos >>> 16); out.write(pos >>> 8); out.write(pos);
            }
            out.write(buf, 0, pos);
            pos = 0;
        } else if (!blkmode && pos > 0) {
            out.write(buf, 0, pos);
            pos = 0;
        }
    }
    boolean setBlockDataMode(boolean mode) throws IOException {
        if (blkmode == mode) return blkmode;
        drain();
        blkmode = mode;
        return !blkmode;
    }
    private void writeRaw1(int v) throws IOException {
        if (pos >= BUFSIZE) writeBlockHeaderAndData();
        buf[pos++] = (byte) v;
    }
    private void writeByteRaw(int v) throws IOException { writeRaw1(v); }
    private void writeRaw2(int v) throws IOException {
        if (pos + 2 > BUFSIZE) writeBlockHeaderAndData();
        buf[pos++] = (byte) (v >>> 8);
        buf[pos++] = (byte) v;
    }
    private void writeShortRaw(int v) throws IOException { writeRaw2(v); }
    private void writeRaw4(int v) throws IOException {
        if (pos + 4 > BUFSIZE) writeBlockHeaderAndData();
        buf[pos++] = (byte) (v >>> 24); buf[pos++] = (byte) (v >>> 16); buf[pos++] = (byte) (v >>> 8); buf[pos++] = (byte) v;
    }
    private void writeRaw8(long v) throws IOException {
        if (pos + 8 > BUFSIZE) writeBlockHeaderAndData();
        for (int i = 56; i >= 0; i -= 8) buf[pos++] = (byte) (v >>> i);
    }
    private void writeBytesRaw(byte[] b, int off, int len) throws IOException {
        if (!(blkmode)) {
            drain();
            out.write(b, off, len);
            return;
        }
        while (len > 0) {
            if (pos >= BUFSIZE) writeBlockHeaderAndData();
            int wlen = Math.min(len, BUFSIZE - pos);
            System.arraycopy(b, off, buf, pos, wlen);
            pos += wlen; off += wlen; len -= wlen;
        }
    }
    private static int utfLen(String s) {
        int n = s.length(), l = n;
        for (int i = 0; i < n; i++) {
            int c = s.charAt(i);
            if (c >= 0x80 || c == 0) l += (c >= 0x800) ? 2 : 1;
        }
        return l;
    }
    private void writeUTFBody(String s) throws IOException {
        int n = s.length();
        for (int i = 0; i < n; i++) {
            int c = s.charAt(i);
            if (c >= 0x0001 && c <= 0x007F) writeRaw1(c);
            else if (c > 0x07FF) {
                writeRaw1(0xE0 | ((c >> 12) & 0x0F));
                writeRaw1(0x80 | ((c >> 6) & 0x3F));
                writeRaw1(0x80 | (c & 0x3F));
            } else {
                writeRaw1(0xC0 | ((c >> 6) & 0x1F));
                writeRaw1(0x80 | (c & 0x3F));
            }
        }
    }

    // ----- table des identifiants ------------------------------------------------
    private int hlookup(Object o) {
        int mask = hobjs.length - 1;
        int i = (System.identityHashCode(o) * 0x9E3779B1 >>> 7) & mask;
        while (hobjs[i] != null) {
            if (hobjs[i] == o) return hids[i];
            i = (i + 1) & mask;
        }
        return -1;
    }
    private int hassign(Object o) {
        int id = hnext++;
        if (o == null) return id;
        if (hcount * 2 >= hobjs.length) {
            Object[] oo = hobjs; int[] oi = hids;
            hobjs = new Object[oo.length * 2]; hids = new int[oo.length * 2];
            hcount = 0;
            for (int k = 0; k < oo.length; k++) if (oo[k] != null) hput(oo[k], oi[k]);
        }
        hput(o, id);
        return id;
    }
    private void hput(Object o, int id) {
        int mask = hobjs.length - 1;
        int i = (System.identityHashCode(o) * 0x9E3779B1 >>> 7) & mask;
        while (hobjs[i] != null) i = (i + 1) & mask;
        hobjs[i] = o; hids[i] = id; hcount++;
    }
    private void clearHandles() {
        hobjs = new Object[16]; hids = new int[16]; hcount = 0; hnext = 0;
    }

    // ----- ecriture des objets -----------------------------------------------------
    private void writeObject0(Object obj, boolean unshared) throws IOException {
        boolean oldMode = setBlockDataMode(false);
        depth++;
        try {
            int h;
            if ((obj = subs(obj)) == null) { writeNull(); return; }
            else if (!unshared && (h = hlookup(obj)) != -1) { writeHandle(h); return; }
            else if (obj instanceof Class) { writeClass((Class<?>) obj, unshared); return; }
            else if (obj instanceof ObjectStreamClass) { writeClassDesc((ObjectStreamClass) obj, unshared); return; }
            Object orig = obj;
            Class<?> cl = obj.getClass();
            ObjectStreamClass desc;
            for (;;) {
                Class<?> repCl;
                desc = ObjectStreamClass.lookup(cl, true);
                if (!desc.hasWriteReplaceMethod() || (obj = desc.invokeWriteReplace(obj)) == null || (repCl = obj.getClass()) == cl) break;
                cl = repCl;
            }
            if (enableReplace) {
                Object rep = replaceObject(obj);
                if (rep != obj && rep != null) {
                    cl = rep.getClass();
                    desc = ObjectStreamClass.lookup(cl, true);
                }
                obj = rep;
            }
            if (obj != orig) {
                obj = subs(obj);
                if (obj == null) { writeNull(); return; }
                if (!unshared && (h = hlookup(obj)) != -1) { writeHandle(h); return; }
                else if (obj instanceof Class) { writeClass((Class<?>) obj, unshared); return; }
                else if (obj instanceof ObjectStreamClass) { writeClassDesc((ObjectStreamClass) obj, unshared); return; }
            }
            if (obj instanceof String) writeString((String) obj, unshared);
            else if (cl.isArray()) writeArray(obj, desc, unshared);
            else if (obj instanceof Enum) writeEnum((Enum<?>) obj, desc, unshared);
            else if (obj instanceof Serializable) writeOrdinaryObject(obj, desc, unshared);
            else {
                if (abortMsg()) throw new NotSerializableException(cl.getName());
                throw new NotSerializableException(cl.getName());
            }
        } finally {
            depth--;
            setBlockDataMode(oldMode);
        }
    }
    private boolean abortMsg() { return false; }
    private Object subs(Object o) { return o; }
    private void writeNull() throws IOException { writeByteRaw(TC_NULL); }
    private void writeHandle(int handle) throws IOException {
        writeByteRaw(TC_REFERENCE);
        writeRaw4(baseWireHandle + handle);
    }
    private void writeClass(Class<?> cl, boolean unshared) throws IOException {
        writeByteRaw(TC_CLASS);
        writeClassDesc(ObjectStreamClass.lookup(cl, true), false);
        hassign(unshared ? null : cl);
    }
    private void writeClassDesc(ObjectStreamClass desc, boolean unshared) throws IOException {
        int handle;
        if (desc == null) writeNull();
        else if (!unshared && (handle = hlookup(desc)) != -1) writeHandle(handle);
        else if (desc.isProxy()) writeProxyDesc(desc, unshared);
        else writeNonProxyDesc(desc, unshared);
    }
    private void writeProxyDesc(ObjectStreamClass desc, boolean unshared) throws IOException {
        writeByteRaw(TC_PROXYCLASSDESC);
        hassign(unshared ? null : desc);
        Class<?> cl = desc.forClass();
        Class<?>[] ifaces = cl.getInterfaces();
        writeRaw4(ifaces.length);
        for (int i = 0; i < ifaces.length; i++) writeUTF(ifaces[i].getName());
        boolean old = setBlockDataMode(true);
        annotateProxyClass(cl);
        setBlockDataMode(old);
        writeByteRaw(TC_ENDBLOCKDATA);
        writeClassDesc(desc.getSuperDesc(), false);
    }
    private void writeNonProxyDesc(ObjectStreamClass desc, boolean unshared) throws IOException {
        writeByteRaw(TC_CLASSDESC);
        hassign(unshared ? null : desc);
        if (protocol == PROTOCOL_VERSION_1) desc.writeNonProxy(this);
        else desc.writeNonProxy(this);
        Class<?> cl = desc.forClass();
        boolean old = setBlockDataMode(true);
        annotateClass(cl);
        setBlockDataMode(old);
        writeByteRaw(TC_ENDBLOCKDATA);
        writeClassDesc(desc.getSuperDesc(), false);
    }
    void writeTypeString(String str) throws IOException {
        int handle;
        if (str == null) writeNull();
        else if ((handle = hlookup(str)) != -1) writeHandle(handle);
        else writeString(str, false);
    }
    private void writeString(String str, boolean unshared) throws IOException {
        hassign(unshared ? null : str);
        long utflen = utfLen(str);
        if (utflen <= 0xFFFF) {
            writeByteRaw(TC_STRING);
            writeRaw2((int) utflen);
        } else {
            writeByteRaw(TC_LONGSTRING);
            writeRaw8(utflen);
        }
        writeUTFBody(str);
    }
    private void writeArray(Object array, ObjectStreamClass desc, boolean unshared) throws IOException {
        writeByteRaw(TC_ARRAY);
        writeClassDesc(desc, false);
        hassign(unshared ? null : array);
        Class<?> ccl = desc.forClass().getComponentType();
        if (ccl.isPrimitive()) {
            if (ccl == Integer.TYPE) {
                int[] ia = (int[]) array;
                writeRaw4(ia.length);
                for (int i = 0; i < ia.length; i++) writeRaw4(ia[i]);
            } else if (ccl == Byte.TYPE) {
                byte[] ba = (byte[]) array;
                writeRaw4(ba.length);
                writeRawBytesDirect(ba, 0, ba.length);
            } else if (ccl == Long.TYPE) {
                long[] ja = (long[]) array;
                writeRaw4(ja.length);
                for (int i = 0; i < ja.length; i++) writeRaw8(ja[i]);
            } else if (ccl == Float.TYPE) {
                float[] fa = (float[]) array;
                writeRaw4(fa.length);
                for (int i = 0; i < fa.length; i++) writeRaw4(Float.floatToIntBits(fa[i]));
            } else if (ccl == Double.TYPE) {
                double[] da = (double[]) array;
                writeRaw4(da.length);
                for (int i = 0; i < da.length; i++) writeRaw8(Double.doubleToLongBits(da[i]));
            } else if (ccl == Short.TYPE) {
                short[] sa = (short[]) array;
                writeRaw4(sa.length);
                for (int i = 0; i < sa.length; i++) writeRaw2(sa[i]);
            } else if (ccl == Character.TYPE) {
                char[] ca = (char[]) array;
                writeRaw4(ca.length);
                for (int i = 0; i < ca.length; i++) writeRaw2(ca[i]);
            } else if (ccl == Boolean.TYPE) {
                boolean[] za = (boolean[]) array;
                writeRaw4(za.length);
                for (int i = 0; i < za.length; i++) writeRaw1(za[i] ? 1 : 0);
            } else throw new InternalError();
        } else {
            Object[] objs = (Object[]) array;
            int len = objs.length;
            writeRaw4(len);
            for (int i = 0; i < len; i++) writeObject0(objs[i], false);
        }
    }
    private void writeRawBytesDirect(byte[] b, int off, int len) throws IOException {
        for (int i = 0; i < len; i++) writeRaw1(b[off + i]);
    }
    private void writeEnum(Enum<?> en, ObjectStreamClass desc, boolean unshared) throws IOException {
        writeByteRaw(TC_ENUM);
        ObjectStreamClass sdesc = desc.getSuperDesc();
        writeClassDesc((sdesc.forClass() == Enum.class) ? desc : sdesc, false);
        hassign(unshared ? null : en);
        writeString(en.name(), false);
    }
    private void writeOrdinaryObject(Object obj, ObjectStreamClass desc, boolean unshared) throws IOException {
        writeByteRaw(TC_OBJECT);
        writeClassDesc(desc, false);
        hassign(unshared ? null : obj);
        if (desc.isExternalizable() && !desc.isProxy()) writeExternalData((Externalizable) obj);
        else writeSerialData(obj, desc);
    }
    private void writeExternalData(Externalizable obj) throws IOException {
        PutFieldImpl oldPut = curPut;
        curPut = null;
        Object oldObj = curObj;
        ObjectStreamClass oldDesc = curDesc;
        curObj = obj;
        curDesc = null;
        if (protocol == PROTOCOL_VERSION_1) obj.writeExternal(this);
        else {
            boolean old = setBlockDataMode(true);
            obj.writeExternal(this);
            setBlockDataMode(false);
            writeByteRaw(TC_ENDBLOCKDATA);
            setBlockDataMode(old);
        }
        curObj = oldObj;
        curDesc = oldDesc;
        curPut = oldPut;
    }
    private void writeSerialData(Object obj, ObjectStreamClass desc) throws IOException {
        ObjectStreamClass[] layout = desc.getLayout();
        for (int i = 0; i < layout.length; i++) {
            ObjectStreamClass slotDesc = layout[i];
            if (slotDesc.hasWriteObjectMethod()) {
                PutFieldImpl oldPut = curPut;
                curPut = null;
                Object oldObj = curObj;
                ObjectStreamClass oldDesc = curDesc;
                curObj = obj;
                curDesc = slotDesc;
                boolean old = setBlockDataMode(true);
                try {
                    slotDesc.invokeWriteObject(obj, this);
                } finally { }
                setBlockDataMode(false);
                writeByteRaw(TC_ENDBLOCKDATA);
                setBlockDataMode(old);
                curObj = oldObj;
                curDesc = oldDesc;
                curPut = oldPut;
            } else {
                defaultWriteFields(obj, slotDesc);
            }
        }
    }
    private void defaultWriteFields(Object obj, ObjectStreamClass desc) throws IOException {
        Class<?> cl = desc.forClass();
        if (cl != null && obj != null && !cl.isInstance(obj)) throw new ClassCastException();
        ObjectStreamField[] fields = desc.getFieldsInternal();
        // primitives d'abord (tries en premier), puis objets
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i];
            if (!f.isPrimitive()) continue;
            Field fl = f.getField();
            if (fl == null) continue;
            fl.setAccessible(true);
            try {
                switch (f.getTypeCode()) {
                    case 'Z': writeRaw1(fl.getBoolean(obj) ? 1 : 0); break;
                    case 'B': writeRaw1(fl.getByte(obj)); break;
                    case 'C': writeRaw2(fl.getChar(obj)); break;
                    case 'S': writeRaw2(fl.getShort(obj)); break;
                    case 'I': writeRaw4(fl.getInt(obj)); break;
                    case 'F': writeRaw4(Float.floatToIntBits(fl.getFloat(obj))); break;
                    case 'J': writeRaw8(fl.getLong(obj)); break;
                    case 'D': writeRaw8(Double.doubleToLongBits(fl.getDouble(obj))); break;
                }
            } catch (IllegalAccessException e) { throw new InternalError(e.toString()); }
        }
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i];
            if (f.isPrimitive()) continue;
            Field fl = f.getField();
            Object v = null;
            if (fl != null) {
                fl.setAccessible(true);
                try { v = fl.get(obj); } catch (IllegalAccessException e) { throw new InternalError(e.toString()); }
            }
            writeObject0(v, f.isUnshared());
        }
    }
    private void writeFatalException(IOException ex) throws IOException {
        clearHandles();
        boolean old = setBlockDataMode(false);
        try {
            writeByteRaw(TC_EXCEPTION);
            writeObject0(ex, false);
            clearHandles();
        } finally { setBlockDataMode(old); }
    }

    public abstract static class PutField {
        public abstract void put(String name, boolean val);
        public abstract void put(String name, byte val);
        public abstract void put(String name, char val);
        public abstract void put(String name, short val);
        public abstract void put(String name, int val);
        public abstract void put(String name, long val);
        public abstract void put(String name, float val);
        public abstract void put(String name, double val);
        public abstract void put(String name, Object val);
        @Deprecated public abstract void write(ObjectOutput out) throws IOException;
    }
    private final class PutFieldImpl extends PutField {
        private final ObjectStreamClass desc;
        private final HashMap<String, Object> vals = new HashMap<>();
        PutFieldImpl(ObjectStreamClass desc) { this.desc = desc; }
        private void chk(String name) {
            if (desc.getField(name) == null) throw new IllegalArgumentException("no such field " + name);
        }
        public void put(String name, boolean val) { chk(name); vals.put(name, Boolean.valueOf(val)); }
        public void put(String name, byte val) { chk(name); vals.put(name, Byte.valueOf(val)); }
        public void put(String name, char val) { chk(name); vals.put(name, Character.valueOf(val)); }
        public void put(String name, short val) { chk(name); vals.put(name, Short.valueOf(val)); }
        public void put(String name, int val) { chk(name); vals.put(name, Integer.valueOf(val)); }
        public void put(String name, long val) { chk(name); vals.put(name, Long.valueOf(val)); }
        public void put(String name, float val) { chk(name); vals.put(name, Float.valueOf(val)); }
        public void put(String name, double val) { chk(name); vals.put(name, Double.valueOf(val)); }
        public void put(String name, Object val) { chk(name); vals.put(name, val); }
        public void write(ObjectOutput out) throws IOException { throw new UnsupportedOperationException(); }
        void writeFields() throws IOException {
            ObjectStreamField[] fields = desc.getFieldsInternal();
            for (ObjectStreamField f : fields) {
                if (!f.isPrimitive()) continue;
                Object v = vals.get(f.getName());
                switch (f.getTypeCode()) {
                    case 'Z': writeRaw1(v != null && (Boolean) v ? 1 : 0); break;
                    case 'B': writeRaw1(v == null ? 0 : (Byte) v); break;
                    case 'C': writeRaw2(v == null ? 0 : (Character) v); break;
                    case 'S': writeRaw2(v == null ? 0 : (Short) v); break;
                    case 'I': writeRaw4(v == null ? 0 : (Integer) v); break;
                    case 'F': writeRaw4(Float.floatToIntBits(v == null ? 0f : (Float) v)); break;
                    case 'J': writeRaw8(v == null ? 0L : (Long) v); break;
                    case 'D': writeRaw8(Double.doubleToLongBits(v == null ? 0d : (Double) v)); break;
                }
            }
            for (ObjectStreamField f : fields) {
                if (f.isPrimitive()) continue;
                writeObject0(vals.get(f.getName()), f.isUnshared());
            }
        }
    }
}
