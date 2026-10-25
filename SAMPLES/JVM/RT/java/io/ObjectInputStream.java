package java.io;
import java.lang.reflect.*;
import java.util.ArrayList;
import java.util.HashMap;
public class ObjectInputStream extends InputStream implements ObjectInput, ObjectStreamConstants {
    private static final int NULL_HANDLE = -1;
    private final InputStream in;
    private int peekb = -1;
    private boolean blkmode;
    private int unread;
    private boolean eod;
    private final ArrayList<Object> handles = new ArrayList<>();
    private final ArrayList<Object> handleExc = new ArrayList<>();
    private int depth;
    private boolean closed;
    private Object curObj;
    private ObjectStreamClass curDesc;
    private GetFieldImpl curGet;
    private boolean defaultDataEnd;
    private boolean enableResolve;
    private final boolean subclass;
    private ClassNotFoundException pendingCnf;

    public ObjectInputStream(InputStream in) throws IOException {
        this.in = in;
        this.subclass = false;
        readStreamHeader();
        blkmode = true;
    }
    protected ObjectInputStream() throws IOException, SecurityException { this.in = null; this.subclass = true; }
    protected void readStreamHeader() throws IOException, StreamCorruptedException {
        short s0 = readShortRaw();
        short s1 = readShortRaw();
        if (s0 != STREAM_MAGIC || s1 != STREAM_VERSION) throw new StreamCorruptedException(String.format("invalid stream header: %04X%04X", s0, s1));
    }
    public final Object readObject() throws IOException, ClassNotFoundException {
        if (subclass) return readObjectOverride();
        int outerHandle = depth == 0 ? 0 : 1;
        depth++;
        try {
            Object obj = readObject0(false);
            if (depth == 1 && pendingCnf != null) {
                ClassNotFoundException ex = pendingCnf;
                pendingCnf = null;
                throw ex;
            }
            return obj;
        } finally {
            depth--;
            if (depth == 0) { pendingCnf = pendingCnf; }
        }
    }
    protected Object readObjectOverride() throws IOException, ClassNotFoundException { return null; }
    public Object readUnshared() throws IOException, ClassNotFoundException { return readObject(); }
    public void defaultReadObject() throws IOException, ClassNotFoundException {
        if (curObj == null || curDesc == null) throw new NotActiveException("not in call to readObject");
        boolean old = setBlockDataMode(false);
        defaultReadFields(curObj, curDesc);
        setBlockDataMode(old);
        if (!curDesc.hasWriteObjectData()) defaultDataEnd = true;
    }
    public GetField readFields() throws IOException, ClassNotFoundException {
        if (curObj == null || curDesc == null) throw new NotActiveException("not in call to readObject");
        GetFieldImpl g = new GetFieldImpl(curDesc);
        boolean old = setBlockDataMode(false);
        g.readFields();
        setBlockDataMode(old);
        if (!curDesc.hasWriteObjectData()) defaultDataEnd = true;
        return g;
    }
    public void registerValidation(ObjectInputValidation obj, int prio) throws NotActiveException, InvalidObjectException {
        if (depth == 0) throw new NotActiveException("stream inactive");
        if (obj == null) throw new InvalidObjectException("null callback");
        validations.add(obj);
    }
    private final ArrayList<ObjectInputValidation> validations = new ArrayList<>();
    protected Class<?> resolveClass(ObjectStreamClass desc) throws IOException, ClassNotFoundException {
        String name = desc.getName();
        switch (name) {
            case "boolean": return boolean.class;
            case "byte": return byte.class;
            case "char": return char.class;
            case "short": return short.class;
            case "int": return int.class;
            case "long": return long.class;
            case "float": return float.class;
            case "double": return double.class;
            case "void": return void.class;
        }
        return Class.forName(name);
    }
    protected Class<?> resolveProxyClass(String[] interfaces) throws IOException, ClassNotFoundException {
        Class<?>[] cl = new Class<?>[interfaces.length];
        for (int i = 0; i < interfaces.length; i++) cl[i] = Class.forName(interfaces[i]);
        return Proxy.getProxyClass(null, cl);
    }
    protected Object resolveObject(Object obj) throws IOException { return obj; }
    protected boolean enableResolveObject(boolean enable) throws SecurityException {
        boolean old = enableResolve;
        enableResolve = enable;
        return old;
    }

    // ----- couche octets / blocs ----------------------------------------------------
    private int rawRead() throws IOException {
        if (peekb >= 0) { int b = peekb; peekb = -1; return b; }
        return in.read();
    }
    private int rawPeek() throws IOException {
        if (peekb >= 0) return peekb;
        peekb = in.read();
        return peekb;
    }
    private int rawByte() throws IOException {
        int b = rawRead();
        if (b < 0) throw new EOFException();
        return b;
    }
    private short readShortRaw() throws IOException { return (short) ((rawByte() << 8) | rawByte()); }
    private int rawInt() throws IOException { return (rawByte() << 24) | (rawByte() << 16) | (rawByte() << 8) | rawByte(); }
    private long rawLong() throws IOException { return ((long) rawInt() << 32) | (rawInt() & 0xFFFFFFFFL); }
    /** s'assure d'avoir des octets de bloc disponibles ; faux a la fin des donnees de bloc */
    private boolean refill() throws IOException {
        while (unread == 0) {
            if (eod) return false;
            int tc = rawPeek();
            if (tc == TC_BLOCKDATA) {
                rawRead();
                int len = rawByte();
                unread = len;
            } else if (tc == TC_BLOCKDATALONG) {
                rawRead();
                int len = rawInt();
                if (len < 0) throw new StreamCorruptedException("illegal block data header length: " + len);
                unread = len;
            } else {
                eod = true;
                return false;
            }
        }
        return true;
    }
    private int dataRead() throws IOException {
        if (!blkmode) return rawRead();
        if (!refill()) return -1;
        unread--;
        return rawRead();
    }
    private int dataByte() throws IOException {
        int b = dataRead();
        if (b < 0) throw new EOFException();
        return b;
    }
    boolean setBlockDataMode(boolean newmode) throws IOException {
        if (blkmode == newmode) return blkmode;
        if (newmode) { eod = false; unread = 0; }
        else if (unread > 0) throw new IllegalStateException("unread block data");
        blkmode = newmode;
        return !blkmode;
    }
    private int currentBlockRemaining() { return blkmode ? unread : 0; }
    private void skipBlockData() throws IOException {
        if (!blkmode) throw new IllegalStateException("not in block data mode");
        while (true) {
            while (unread > 0) { rawRead(); unread--; }
            if (!refill()) break;
        }
    }
    private int peekByte() throws IOException {
        int b = rawPeek();
        if (b < 0) throw new EOFException();
        return b;
    }

    public int read() throws IOException {
        if (!blkmode) return rawRead();
        return dataRead();
    }
    public int read(byte[] buf, int off, int len) throws IOException {
        if (buf == null) throw new NullPointerException();
        int endoff = off + len;
        if (off < 0 || len < 0 || endoff > buf.length || endoff < 0) throw new IndexOutOfBoundsException();
        if (len == 0) return 0;
        if (!blkmode) {
            int c = rawRead();
            if (c < 0) return -1;
            buf[off] = (byte) c;
            int n = 1;
            while (n < len && peekb >= 0 || n < len && in.available() > 0) { int d = rawRead(); if (d < 0) break; buf[off + n++] = (byte) d; }
            return n;
        }
        if (!refill()) return -1;
        int n = Math.min(len, unread);
        for (int i = 0; i < n; i++) buf[off + i] = (byte) rawRead();
        unread -= n;
        return n;
    }
    public int available() throws IOException {
        if (blkmode) {
            if (unread > 0) return unread;
            return 0;
        }
        return in.available() + (peekb >= 0 ? 1 : 0);
    }
    public void close() throws IOException { closed = true; if (in != null) in.close(); }
    public boolean readBoolean() throws IOException { return dataByte() != 0; }
    public byte readByte() throws IOException { return (byte) dataByte(); }
    public int readUnsignedByte() throws IOException { return dataByte(); }
    public char readChar() throws IOException { return (char) ((dataByte() << 8) | dataByte()); }
    public short readShort() throws IOException { return (short) ((dataByte() << 8) | dataByte()); }
    public int readUnsignedShort() throws IOException { return (dataByte() << 8) | dataByte(); }
    public int readInt() throws IOException { return (dataByte() << 24) | (dataByte() << 16) | (dataByte() << 8) | dataByte(); }
    public float readFloat() throws IOException { return Float.intBitsToFloat(readInt()); }
    public long readLong() throws IOException { return ((long) readInt() << 32) | (readInt() & 0xFFFFFFFFL); }
    public double readDouble() throws IOException { return Double.longBitsToDouble(readLong()); }
    public void readFully(byte[] buf) throws IOException { readFully(buf, 0, buf.length); }
    public void readFully(byte[] buf, int off, int len) throws IOException {
        for (int i = 0; i < len; i++) buf[off + i] = (byte) dataByte();
    }
    public int skipBytes(int len) throws IOException {
        int n = 0;
        while (n < len && dataRead() >= 0) n++;
        return n;
    }
    @Deprecated public String readLine() throws IOException {
        StringBuilder sb = new StringBuilder();
        int c = dataRead();
        if (c < 0) return null;
        while (c >= 0 && c != '\n') { if (c != '\r') sb.append((char) c); c = dataRead(); }
        return sb.toString();
    }
    public String readUTF() throws IOException {
        int len = readUnsignedShort();
        return readUTFBody(len);
    }
    private String readUTFBody(long utflen) throws IOException {
        StringBuilder sb = new StringBuilder();
        boolean old = blkmode;
        long remaining = utflen;
        while (remaining > 0) {
            int c = dataByte() & 0xff;
            remaining--;
            switch (c >> 4) {
                case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7:
                    sb.append((char) c);
                    break;
                case 12: case 13: {
                    if (remaining < 1) throw new UTFDataFormatException();
                    int c2 = dataByte(); remaining--;
                    if ((c2 & 0xC0) != 0x80) throw new UTFDataFormatException();
                    sb.append((char) (((c & 0x1F) << 6) | (c2 & 0x3F)));
                    break;
                }
                case 14: {
                    if (remaining < 2) throw new UTFDataFormatException();
                    int c2 = dataByte(), c3 = dataByte(); remaining -= 2;
                    if (((c2 & 0xC0) != 0x80) || ((c3 & 0xC0) != 0x80)) throw new UTFDataFormatException();
                    sb.append((char) (((c & 0x0F) << 12) | ((c2 & 0x3F) << 6) | (c3 & 0x3F)));
                    break;
                }
                default: throw new UTFDataFormatException();
            }
        }
        return sb.toString();
    }
    String readTypeString() throws IOException {
        int oldHandle = 0;
        boolean old = setBlockDataMode(false);
        try {
            byte tc = (byte) peekByte();
            switch (tc) {
                case TC_NULL: return (String) readNull();
                case TC_REFERENCE: return (String) readHandle(false);
                case TC_STRING: case TC_LONGSTRING: return readString(false);
                default: throw new StreamCorruptedException(String.format("invalid type code: %02X", tc));
            }
        } finally { setBlockDataMode(old); }
    }

    // ----- lecture des objets ------------------------------------------------------
    private int assignHandle(Object o) {
        handles.add(o);
        handleExc.add(null);
        return handles.size() - 1;
    }
    private void setHandle(int h, Object o) { handles.set(h, o); }
    private Object readObject0(boolean unshared) throws IOException {
        boolean oldMode = blkmode;
        if (oldMode) {
            int remain = currentBlockRemaining();
            if (remain > 0) throw new OptionalDataException(remain);
            else if (defaultDataEnd) throw new OptionalDataException(true);
            setBlockDataMode(false);
        }
        byte tc;
        while ((tc = (byte) peekByte()) == TC_RESET) {
            rawRead();
            handles.clear();
            handleExc.clear();
        }
        depth++;
        try {
            switch (tc) {
                case TC_NULL: return readNull();
                case TC_REFERENCE: return readHandle(unshared);
                case TC_CLASS: return readClass(unshared);
                case TC_CLASSDESC: case TC_PROXYCLASSDESC: return readClassDesc(unshared);
                case TC_STRING: case TC_LONGSTRING: return checkResolve(readString(unshared));
                case TC_ARRAY: return checkResolve(readArray(unshared));
                case TC_ENUM: return checkResolve(readEnum(unshared));
                case TC_OBJECT: return checkResolve(readOrdinaryObject(unshared));
                case TC_EXCEPTION: {
                    IOException ex = readFatalException();
                    throw new WriteAbortedException("writing aborted", ex);
                }
                case TC_BLOCKDATA: case TC_BLOCKDATALONG:
                    if (oldMode) {
                        setBlockDataMode(true);
                        refill();
                        throw new OptionalDataException(currentBlockRemaining());
                    } else throw new StreamCorruptedException("unexpected block data");
                case TC_ENDBLOCKDATA:
                    if (oldMode) throw new OptionalDataException(true);
                    else throw new StreamCorruptedException("unexpected end of block data");
                default:
                    throw new StreamCorruptedException(String.format("invalid type code: %02X", tc));
            }
        } finally {
            depth--;
            setBlockDataMode(oldMode);
        }
    }
    private Object checkResolve(Object obj) throws IOException {
        if (!enableResolve) return obj;
        Object rep = resolveObject(obj);
        return rep;
    }
    private Object readNull() throws IOException {
        if (rawRead() != TC_NULL) throw new InternalError();
        return null;
    }
    private Object readHandle(boolean unshared) throws IOException {
        if (rawRead() != TC_REFERENCE) throw new InternalError();
        int h = rawInt() - baseWireHandle;
        if (h < 0 || h >= handles.size()) throw new StreamCorruptedException(String.format("invalid handle value: %08X", h + baseWireHandle));
        if (unshared) throw new InvalidObjectException("cannot read back reference as unshared");
        Object o = handles.get(h);
        Object ex = handleExc.get(h);
        if (ex != null) { if (pendingCnf == null) pendingCnf = (ClassNotFoundException) ex; }
        return o;
    }
    private Class<?> readClass(boolean unshared) throws IOException {
        if (rawRead() != TC_CLASS) throw new InternalError();
        ObjectStreamClass desc = readClassDesc(false);
        Class<?> cl = desc.forClass();
        int h = assignHandle(cl);
        return cl;
    }
    private ObjectStreamClass readClassDesc(boolean unshared) throws IOException {
        byte tc = (byte) peekByte();
        switch (tc) {
            case TC_NULL: return (ObjectStreamClass) readNull();
            case TC_REFERENCE: return (ObjectStreamClass) readHandle(unshared);
            case TC_PROXYCLASSDESC: return readProxyDesc(unshared);
            case TC_CLASSDESC: return readNonProxyDesc(unshared);
            default: throw new StreamCorruptedException(String.format("invalid type code: %02X", tc));
        }
    }
    private ObjectStreamClass readProxyDesc(boolean unshared) throws IOException {
        if (rawRead() != TC_PROXYCLASSDESC) throw new InternalError();
        ObjectStreamClass desc = new ObjectStreamClass();
        int h = assignHandle(desc);
        int numIfaces = rawInt();
        String[] ifaces = new String[numIfaces];
        boolean old = setBlockDataMode(false);
        for (int i = 0; i < numIfaces; i++) ifaces[i] = readUTFRaw();
        Class<?> cl = null;
        ClassNotFoundException resolveEx = null;
        setBlockDataMode(true);
        try { cl = resolveProxyClass(ifaces); } catch (ClassNotFoundException ex) { resolveEx = ex; }
        skipCustomData();
        desc.initProxy(cl, readClassDesc(false));
        if (resolveEx != null) handleExc.set(h, resolveEx);
        setBlockDataMode(old);
        return desc;
    }
    private String readUTFRaw() throws IOException {
        int len = (rawByte() << 8) | rawByte();
        return rawUTF(len);
    }
    private String rawUTF(long utflen) throws IOException {
        boolean old = blkmode;
        blkmode = false;
        try { return readUTFBody(utflen); } finally { blkmode = old; }
    }
    private ObjectStreamClass readNonProxyDesc(boolean unshared) throws IOException {
        if (rawRead() != TC_CLASSDESC) throw new InternalError();
        ObjectStreamClass desc = new ObjectStreamClass();
        int h = assignHandle(desc);
        ObjectStreamClass readDesc;
        boolean old = setBlockDataMode(false);
        try {
            try {
                readDesc = new ObjectStreamClass();
                readDescBody(readDesc);
            } catch (ClassNotFoundException ex) { throw new InternalError(); }
        } finally { }
        Class<?> cl = null;
        ClassNotFoundException resolveEx = null;
        setBlockDataMode(true);
        try { cl = resolveClass(readDesc); } catch (ClassNotFoundException ex) { resolveEx = ex; }
        skipCustomData();
        ObjectStreamClass sup = readClassDesc(false);
        try {
            desc.initNonProxy(readDesc, cl, sup);
        } catch (InvalidClassException ex) {
            setBlockDataMode(old);
            throw ex;
        }
        if (resolveEx != null) handleExc.set(h, resolveEx);
        setBlockDataMode(old);
        return desc;
    }
    private void readDescBody(ObjectStreamClass d) throws IOException, ClassNotFoundException { d.readNonProxy(this); }
    private void skipCustomData() throws IOException {
        for (;;) {
            if (blkmode) {
                skipBlockData();
                setBlockDataMode(false);
            }
            switch ((byte) peekByte()) {
                case TC_BLOCKDATA: case TC_BLOCKDATALONG:
                    setBlockDataMode(true);
                    break;
                case TC_ENDBLOCKDATA:
                    rawRead();
                    return;
                default:
                    readObject0(false);
                    break;
            }
        }
    }
    private String readString(boolean unshared) throws IOException {
        String str;
        byte tc = (byte) rawRead();
        switch (tc) {
            case TC_STRING: str = rawUTF((rawByte() << 8) | rawByte()); break;
            case TC_LONGSTRING: str = rawUTF(rawLong()); break;
            default: throw new StreamCorruptedException(String.format("invalid type code: %02X", tc));
        }
        assignHandle(str);
        return str;
    }
    private Object readArray(boolean unshared) throws IOException {
        if (rawRead() != TC_ARRAY) throw new InternalError();
        ObjectStreamClass desc = readClassDesc(false);
        int len = rawInt();
        Object array = null;
        Class<?> cl, ccl = null;
        if ((cl = desc.forClass()) != null) {
            ccl = cl.getComponentType();
            array = java.lang.reflect.Array.newInstance(ccl, len);
        }
        int h = assignHandle(array);
        if (ccl == null) {
            for (int i = 0; i < len; i++) readObject0(false);
        } else if (ccl.isPrimitive()) {
            if (ccl == Integer.TYPE) { int[] a = (int[]) array; for (int i = 0; i < len; i++) a[i] = rawInt(); }
            else if (ccl == Byte.TYPE) { byte[] a = (byte[]) array; for (int i = 0; i < len; i++) a[i] = (byte) rawByte(); }
            else if (ccl == Long.TYPE) { long[] a = (long[]) array; for (int i = 0; i < len; i++) a[i] = rawLong(); }
            else if (ccl == Float.TYPE) { float[] a = (float[]) array; for (int i = 0; i < len; i++) a[i] = Float.intBitsToFloat(rawInt()); }
            else if (ccl == Double.TYPE) { double[] a = (double[]) array; for (int i = 0; i < len; i++) a[i] = Double.longBitsToDouble(rawLong()); }
            else if (ccl == Short.TYPE) { short[] a = (short[]) array; for (int i = 0; i < len; i++) a[i] = readShortRaw(); }
            else if (ccl == Character.TYPE) { char[] a = (char[]) array; for (int i = 0; i < len; i++) a[i] = (char) readShortRaw(); }
            else if (ccl == Boolean.TYPE) { boolean[] a = (boolean[]) array; for (int i = 0; i < len; i++) a[i] = rawByte() != 0; }
            else throw new InternalError();
        } else {
            Object[] oa = (Object[]) array;
            for (int i = 0; i < len; i++) oa[i] = readObject0(false);
        }
        return array;
    }
    private Enum<?> readEnum(boolean unshared) throws IOException {
        if (rawRead() != TC_ENUM) throw new InternalError();
        ObjectStreamClass desc = readClassDesc(false);
        if (!desc.isEnum()) throw new InvalidClassException("non-enum class: " + desc);
        int h = assignHandle(null);
        String name = readString(false);
        Enum<?> result = null;
        Class<?> cl = desc.forClass();
        if (cl != null) {
            try {
                Enum<?> en = Enum.valueOf((Class) cl, name);
                result = en;
            } catch (IllegalArgumentException ex) {
                throw (IOException) new InvalidObjectException("enum constant " + name + " does not exist in " + cl).initCause(ex);
            }
            setHandle(h, result);
        }
        return result;
    }
    private Object readOrdinaryObject(boolean unshared) throws IOException {
        if (rawRead() != TC_OBJECT) throw new InternalError();
        ObjectStreamClass desc = readClassDesc(false);
        desc.checkDeserialize();
        Class<?> cl = desc.forClass();
        if (cl == java.lang.String.class || cl == Class.class || cl == ObjectStreamClass.class) throw new InvalidClassException("invalid class descriptor");
        Object obj;
        try {
            obj = (desc.isInstantiable() && !desc.isRecord()) ? desc.newInstance() : null;
        } catch (Exception ex) {
            throw (IOException) new InvalidClassException(desc.getName(), "unable to create instance").initCause(ex);
        }
        if (cl != null && !desc.isRecord() && obj == null && desc.getCons() == null && desc.isSerializable())
            throw new InvalidClassException(desc.getName(), "no valid constructor");
        int h = assignHandle(obj);
        if (desc.isRecord() && cl != null) {
            Object rec = readRecord(desc);
            setHandle(h, rec);
            return rec;
        }
        if (desc.isExternalizable()) readExternalData((Externalizable) obj, desc);
        else readSerialData(obj, desc);
        if (obj != null && desc.hasReadResolveMethod()) {
            Object rep = desc.invokeReadResolve(obj);
            if (rep != obj) { obj = rep; setHandle(h, rep); }
        }
        return obj;
    }
    private Object readRecord(ObjectStreamClass desc) throws IOException {
        ObjectStreamField[] fields = desc.getFieldsInternal();
        Object[] vals = new Object[fields.length];
        for (int i = 0; i < fields.length; i++) {
            if (fields[i].isPrimitive()) vals[i] = readPrimValue(fields[i].getTypeCode());
        }
        for (int i = 0; i < fields.length; i++) {
            if (!fields[i].isPrimitive()) {
                try { vals[i] = readObject0(false); } catch (OptionalDataException e) { throw e; }
            }
        }
        Class<?> cl = desc.forClass();
        java.lang.reflect.RecordComponent[] rcs = cl.getRecordComponents();
        Class<?>[] ptypes = new Class<?>[rcs.length];
        Object[] args = new Object[rcs.length];
        for (int i = 0; i < rcs.length; i++) {
            ptypes[i] = rcs[i].getType();
            Object v = null;
            for (int k = 0; k < fields.length; k++) if (fields[k].getName().equals(rcs[i].getName())) v = vals[k];
            if (v == null && ptypes[i].isPrimitive()) v = defaultPrim(ptypes[i]);
            args[i] = v;
        }
        try {
            Constructor<?> c = cl.getDeclaredConstructor(ptypes);
            c.setAccessible(true);
            return c.newInstance(args);
        } catch (InvocationTargetException e) {
            throw (IOException) new InvalidObjectException(e.getCause().getMessage()).initCause(e.getCause());
        } catch (Exception e) {
            throw (IOException) new InvalidClassException(desc.getName(), "cannot deserialize").initCause(e);
        }
    }
    private static Object defaultPrim(Class<?> t) {
        if (t == int.class) return 0;
        if (t == long.class) return 0L;
        if (t == boolean.class) return false;
        if (t == double.class) return 0d;
        if (t == float.class) return 0f;
        if (t == char.class) return (char) 0;
        if (t == short.class) return (short) 0;
        return (byte) 0;
    }
    private Object readPrimValue(char tc) throws IOException {
        switch (tc) {
            case 'Z': return rawByte() != 0;
            case 'B': return (byte) rawByte();
            case 'C': return (char) readShortRaw();
            case 'S': return readShortRaw();
            case 'I': return rawInt();
            case 'F': return Float.intBitsToFloat(rawInt());
            case 'J': return rawLong();
            case 'D': return Double.longBitsToDouble(rawLong());
        }
        throw new InternalError();
    }
    private void readExternalData(Externalizable obj, ObjectStreamClass desc) throws IOException {
        Object oldObj = curObj;
        ObjectStreamClass oldDesc = curDesc;
        GetFieldImpl oldGet = curGet;
        boolean blocked = desc.hasBlockExternalData();
        curObj = null; curDesc = null; curGet = null;
        boolean old = false;
        if (blocked) old = setBlockDataMode(true);
        if (obj != null) {
            try {
                obj.readExternal(this);
            } catch (ClassNotFoundException ex) {
                if (pendingCnf == null) pendingCnf = ex;
            }
        }
        if (blocked) {
            skipCustomData();
            setBlockDataMode(old);
        }
        curObj = oldObj; curDesc = oldDesc; curGet = oldGet;
    }
    private void readSerialData(Object obj, ObjectStreamClass desc) throws IOException {
        ObjectStreamClass[] layout = desc.getLayout();
        for (int i = 0; i < layout.length; i++) {
            ObjectStreamClass slotDesc = layout[i];
            if (obj != null && slotDesc.hasReadObjectMethod()) {
                Object oldObj = curObj;
                ObjectStreamClass oldDesc = curDesc;
                GetFieldImpl oldGet = curGet;
                boolean oldDefault = defaultDataEnd;
                curObj = obj; curDesc = slotDesc; curGet = null;
                defaultDataEnd = false;
                boolean old = setBlockDataMode(true);
                try {
                    slotDesc.invokeReadObject(obj, this);
                } catch (ClassNotFoundException ex) {
                    if (pendingCnf == null) pendingCnf = ex;
                } finally {
                    curObj = oldObj; curDesc = oldDesc; curGet = oldGet;
                    defaultDataEnd = oldDefault;
                }
                if (slotDesc.hasWriteObjectData()) skipCustomData();
                else setBlockDataMode(false);
                setBlockDataMode(old);
            } else {
                boolean old = setBlockDataMode(false);
                defaultReadFields(obj, slotDesc);
                if (slotDesc.hasWriteObjectData()) { setBlockDataMode(true); skipCustomData(); }
                setBlockDataMode(old);
            }
        }
    }
    private void defaultReadFields(Object obj, ObjectStreamClass desc) throws IOException {
        Class<?> cl = desc.forClass();
        if (cl != null && obj != null && !cl.isInstance(obj)) throw new ClassCastException();
        ObjectStreamField[] fields = desc.getFieldsInternal();
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i];
            if (!f.isPrimitive()) continue;
            Object v = readPrimValue(f.getTypeCode());
            Field fl = f.getField();
            if (obj == null || fl == null) continue;
            fl.setAccessible(true);
            try { fl.set(obj, v); } catch (IllegalAccessException e) { throw new InternalError(e.toString()); }
        }
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i];
            if (f.isPrimitive()) continue;
            Object v = readObject0(f.isUnshared());
            Field fl = f.getField();
            if (obj == null || fl == null) continue;
            fl.setAccessible(true);
            try { fl.set(obj, v); }
            catch (IllegalArgumentException e) { throw (IOException) new ClassCastException("cannot assign instance to field " + cl.getName() + "." + f.getName()).initCause(e); }
            catch (IllegalAccessException e) { throw new InternalError(e.toString()); }
        }
    }
    private IOException readFatalException() throws IOException {
        if (rawRead() != TC_EXCEPTION) throw new InternalError();
        handles.clear();
        handleExc.clear();
        IOException e = (IOException) readObject0(false);
        handles.clear();
        handleExc.clear();
        return e;
    }

    public abstract static class GetField {
        public abstract ObjectStreamClass getObjectStreamClass();
        public abstract boolean defaulted(String name) throws IOException;
        public abstract boolean get(String name, boolean val) throws IOException;
        public abstract byte get(String name, byte val) throws IOException;
        public abstract char get(String name, char val) throws IOException;
        public abstract short get(String name, short val) throws IOException;
        public abstract int get(String name, int val) throws IOException;
        public abstract long get(String name, long val) throws IOException;
        public abstract float get(String name, float val) throws IOException;
        public abstract double get(String name, double val) throws IOException;
        public abstract Object get(String name, Object val) throws IOException;
    }
    private final class GetFieldImpl extends GetField {
        private final ObjectStreamClass desc;
        private final HashMap<String, Object> vals = new HashMap<>();
        GetFieldImpl(ObjectStreamClass desc) { this.desc = desc; }
        void readFields() throws IOException {
            ObjectStreamField[] fields = desc.getFieldsInternal();
            for (ObjectStreamField f : fields) if (f.isPrimitive()) vals.put(f.getName(), readPrimValue(f.getTypeCode()));
            for (ObjectStreamField f : fields) if (!f.isPrimitive()) vals.put(f.getName(), readObject0(f.isUnshared()));
        }
        public ObjectStreamClass getObjectStreamClass() { return desc; }
        public boolean defaulted(String name) throws IOException {
            if (desc.getField(name) == null) throw new IllegalArgumentException("no such field " + name);
            return !vals.containsKey(name);
        }
        private Object v(String name, Object dflt) { Object o = vals.get(name); return o == null ? dflt : o; }
        public boolean get(String name, boolean val) { return (Boolean) v(name, val); }
        public byte get(String name, byte val) { return (Byte) v(name, val); }
        public char get(String name, char val) { return (Character) v(name, val); }
        public short get(String name, short val) { return (Short) v(name, val); }
        public int get(String name, int val) { return (Integer) v(name, val); }
        public long get(String name, long val) { return (Long) v(name, val); }
        public float get(String name, float val) { return (Float) v(name, val); }
        public double get(String name, double val) { return (Double) v(name, val); }
        public Object get(String name, Object val) { return v(name, val); }
    }
}
