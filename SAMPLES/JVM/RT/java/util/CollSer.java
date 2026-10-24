package java.util;
import java.io.*;
final class CollSer implements Serializable {
    private static final long serialVersionUID = 6309168927139932177L;
    static final int IMM_LIST = 0x1;
    static final int IMM_SET = 0x2;
    static final int IMM_MAP = 0x3;
    static final int IMM_LIST_NULLS = 0x4;
    private final int tag;
    private transient Object[] array;
    CollSer(int t, Object... a) { tag = t; array = a; }
    private void readObject(ObjectInputStream ois) throws IOException, ClassNotFoundException {
        ois.defaultReadObject();
        int len = ois.readInt();
        if (len < 0) throw new InvalidObjectException("negative length " + len);
        Object[] a = new Object[len];
        for (int i = 0; i < len; i++) a[i] = ois.readObject();
        array = a;
    }
    private void writeObject(ObjectOutputStream oos) throws IOException {
        oos.defaultWriteObject();
        oos.writeInt(array.length);
        for (int i = 0; i < array.length; i++) oos.writeObject(array[i]);
    }
    private Object readResolve() throws ObjectStreamException {
        if (array == null) throw new InvalidObjectException("null array");
        switch (tag & 0xff) {
            case IMM_LIST: return ImmutableCollections.listOf(array);
            case IMM_LIST_NULLS: return Collections.unmodifiableList(new ArrayList<>(Arrays.asList(array)));
            case IMM_SET: return ImmutableCollections.setOf(array);
            case IMM_MAP: return ImmutableCollections.mapOf(array);
            default: throw new InvalidObjectException(String.format("invalid flags 0x%x", tag));
        }
    }
}
