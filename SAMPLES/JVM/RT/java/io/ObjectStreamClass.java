package java.io;
import java.lang.reflect.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
public class ObjectStreamClass implements Serializable {
    public static final ObjectStreamField[] NO_FIELDS = new ObjectStreamField[0];
    private static final HashMap<Class<?>, ObjectStreamClass> cache = new HashMap<>();
    private Class<?> cl;
    private String name;
    private Long suid;
    private boolean isProxy, isEnum, isRecord, serializable, externalizable;
    boolean hasWriteObjectData, hasBlockExternalData = true;
    private ObjectStreamField[] fields;
    private ObjectStreamClass superDesc;
    private ObjectStreamClass localDesc;
    private Method writeObjectMethod, readObjectMethod, readObjectNoDataMethod, writeReplaceMethod, readResolveMethod;
    private Constructor<?> cons;
    private Field[] fieldRefs;
    private InvalidClassException deserializeEx;
    void checkDeserialize() throws InvalidClassException { if (deserializeEx != null) throw deserializeEx; }
    ObjectStreamClass() {}
    public static ObjectStreamClass lookup(Class<?> cl) { return lookup(cl, false); }
    public static ObjectStreamClass lookupAny(Class<?> cl) { return lookup(cl, true); }
    static ObjectStreamClass lookup(Class<?> cl, boolean all) {
        if (!(all || Serializable.class.isAssignableFrom(cl))) return null;
        synchronized (cache) {
            ObjectStreamClass d = cache.get(cl);
            if (d == null) { d = new ObjectStreamClass(cl); cache.put(cl, d); }
            return d;
        }
    }
    private ObjectStreamClass(final Class<?> cl) {
        this.cl = cl;
        name = cl.getName();
        isProxy = Proxy.isProxyClass(cl);
        isEnum = Enum.class.isAssignableFrom(cl);
        isRecord = cl.isRecord();
        serializable = Serializable.class.isAssignableFrom(cl);
        externalizable = Externalizable.class.isAssignableFrom(cl);
        Class<?> superCl = cl.getSuperclass();
        superDesc = (superCl != null) ? lookup(superCl, false) : null;
        localDesc = this;
        if (serializable) {
            if (isEnum) {
                suid = Long.valueOf(0);
                fields = NO_FIELDS;
                return;
            }
            if (cl.isArray()) {
                fields = NO_FIELDS;
                return;
            }
            suid = getDeclaredSUID(cl);
            if (suid == null && isRecord) suid = Long.valueOf(0);
            try {
                fields = getSerialFields(cl);
                computeFieldOffsets();
            } catch (InvalidClassException e) {
                fields = NO_FIELDS;
            }
            if (externalizable) {
                cons = getExternalizableConstructor(cl);
            } else {
                cons = getSerializableConstructor(cl);
                writeObjectMethod = getPrivateMethod(cl, "writeObject", new Class<?>[]{ObjectOutputStream.class}, Void.TYPE);
                readObjectMethod = getPrivateMethod(cl, "readObject", new Class<?>[]{ObjectInputStream.class}, Void.TYPE);
                readObjectNoDataMethod = getPrivateMethod(cl, "readObjectNoData", null, Void.TYPE);
                hasWriteObjectData = (writeObjectMethod != null);
            }
            writeReplaceMethod = getInheritableMethod(cl, "writeReplace", null, Object.class);
            readResolveMethod = getInheritableMethod(cl, "readResolve", null, Object.class);
        } else {
            suid = Long.valueOf(0);
            fields = NO_FIELDS;
        }
    }
    void initProxy(Class<?> cl, ObjectStreamClass superDesc) {
        this.cl = cl; this.superDesc = superDesc; isProxy = true; serializable = true; suid = 0L; fields = NO_FIELDS;
    }
    /** description lue dans un flux ; local est la description de la classe locale (ou null) */
    void initNonProxy(ObjectStreamClass model, Class<?> cl, ObjectStreamClass superDesc) throws InvalidClassException {
        long suid = Long.valueOf(model.getSerialVersionUID());
        ObjectStreamClass osc = null;
        if (cl != null) {
            osc = lookup(cl, true);
            if (osc.isProxy) throw new InvalidClassException("cannot bind non-proxy descriptor to a proxy class");
            if (model.isEnum != osc.isEnum) throw new InvalidClassException(model.isEnum ? "cannot bind enum descriptor to a non-enum class" : "cannot bind non-enum descriptor to an enum class");
            if (model.serializable == osc.serializable && !cl.isArray() && !cl.isRecord() && suid != osc.getSerialVersionUID()) {
                throw new InvalidClassException(osc.name, "local class incompatible: stream classdesc serialVersionUID = " + suid + ", local class serialVersionUID = " + osc.getSerialVersionUID());
            }
            if (!classNamesEqual(model.name, osc.name)) throw new InvalidClassException(osc.name, "local class name incompatible with stream class name \"" + model.name + "\"");
            if (!model.isEnum) {
                if ((model.serializable == osc.serializable) && (model.externalizable != osc.externalizable))
                    throw new InvalidClassException(osc.name, "Serializable incompatible with Externalizable");
                if ((model.serializable != osc.serializable) || (model.externalizable != osc.externalizable) || !(model.serializable || model.externalizable))
                    deserializeEx = new InvalidClassException(osc.name, "class invalid for deserialization");
            }
        }
        this.cl = cl;
        this.name = model.name;
        this.suid = suid;
        this.isProxy = false;
        this.isEnum = model.isEnum;
        this.serializable = model.serializable;
        this.externalizable = model.externalizable;
        this.hasBlockExternalData = model.hasBlockExternalData;
        this.hasWriteObjectData = model.hasWriteObjectData;
        this.superDesc = superDesc;
        this.isRecord = model.isRecord;
        if (osc != null) {
            localDesc = osc;
            this.writeObjectMethod = localDesc.writeObjectMethod;
            this.readObjectMethod = localDesc.readObjectMethod;
            this.readObjectNoDataMethod = localDesc.readObjectNoDataMethod;
            this.writeReplaceMethod = localDesc.writeReplaceMethod;
            this.readResolveMethod = localDesc.readResolveMethod;
            this.cons = localDesc.cons;
        }
        this.fields = matchFields(model.fields, localDesc);
        computeFieldOffsets();
    }
    private static boolean classNamesEqual(String name1, String name2) {
        int i = name1.lastIndexOf('.'), j = name2.lastIndexOf('.');
        return name1.substring(i + 1).equals(name2.substring(j + 1));
    }
    private static ObjectStreamField[] matchFields(ObjectStreamField[] fields, ObjectStreamClass localDesc) throws InvalidClassException {
        ObjectStreamField[] localFields = (localDesc != null) ? localDesc.fields : NO_FIELDS;
        ObjectStreamField[] matches = new ObjectStreamField[fields.length];
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i], m = null;
            for (int j = 0; j < localFields.length; j++) {
                ObjectStreamField lf = localFields[j];
                if (f.getName().equals(lf.getName())) {
                    if ((f.isPrimitive() || lf.isPrimitive()) && f.getTypeCode() != lf.getTypeCode())
                        throw new InvalidClassException(localDesc.name, "incompatible types for field " + f.getName());
                    if (lf.getField() != null) m = new ObjectStreamField(lf.getField(), lf.isUnshared(), false);
                    else m = new ObjectStreamField(lf.getName(), lf.getSignature(), lf.isUnshared());
                }
            }
            if (m == null) m = new ObjectStreamField(f.getName(), f.getSignature(), false);
            matches[i] = m;
        }
        return matches;
    }
    private int primDataSize, numObjFields;
    private void computeFieldOffsets() {
        primDataSize = 0;
        numObjFields = 0;
        int firstObjIndex = -1;
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i];
            switch (f.getTypeCode()) {
                case 'Z': case 'B': f.setOffset(primDataSize++); break;
                case 'C': case 'S': f.setOffset(primDataSize); primDataSize += 2; break;
                case 'I': case 'F': f.setOffset(primDataSize); primDataSize += 4; break;
                case 'J': case 'D': f.setOffset(primDataSize); primDataSize += 8; break;
                case '[': case 'L': f.setOffset(numObjFields++); if (firstObjIndex == -1) firstObjIndex = i; break;
                default: throw new InternalError();
            }
        }
    }
    int getPrimDataSize() { return primDataSize; }
    int getNumObjFields() { return numObjFields; }
    void writeNonProxy(ObjectOutputStream out) throws IOException {
        out.writeUTF(name);
        out.writeLong(getSerialVersionUID());
        byte flags = 0;
        if (externalizable) {
            flags |= ObjectStreamConstants.SC_EXTERNALIZABLE;
            int protocol = out.getProtocolVersion();
            if (protocol != ObjectStreamConstants.PROTOCOL_VERSION_1) flags |= ObjectStreamConstants.SC_BLOCK_DATA;
        } else if (serializable) flags |= ObjectStreamConstants.SC_SERIALIZABLE;
        if (hasWriteObjectData) flags |= ObjectStreamConstants.SC_WRITE_METHOD;
        if (isEnum) flags |= ObjectStreamConstants.SC_ENUM;
        out.writeByte(flags);
        out.writeShort(fields.length);
        for (int i = 0; i < fields.length; i++) {
            ObjectStreamField f = fields[i];
            out.writeByte(f.getTypeCode());
            out.writeUTF(f.getName());
            if (!f.isPrimitive()) out.writeTypeString(f.getTypeString());
        }
    }
    void readNonProxy(ObjectInputStream in) throws IOException, ClassNotFoundException {
        name = in.readUTF();
        suid = Long.valueOf(in.readLong());
        isProxy = false;
        byte flags = in.readByte();
        hasWriteObjectData = ((flags & ObjectStreamConstants.SC_WRITE_METHOD) != 0);
        hasBlockExternalData = ((flags & ObjectStreamConstants.SC_BLOCK_DATA) != 0);
        externalizable = ((flags & ObjectStreamConstants.SC_EXTERNALIZABLE) != 0);
        boolean sflag = ((flags & ObjectStreamConstants.SC_SERIALIZABLE) != 0);
        if (externalizable && sflag) throw new InvalidClassException(name, "serializable and externalizable flags conflict");
        serializable = externalizable || sflag;
        isEnum = ((flags & ObjectStreamConstants.SC_ENUM) != 0);
        if (isEnum && suid.longValue() != 0L) throw new InvalidClassException(name, "enum descriptor has non-zero serialVersionUID: " + suid);
        int numFields = in.readShort();
        if (isEnum && numFields != 0) throw new InvalidClassException(name, "enum descriptor has non-zero field count: " + numFields);
        fields = (numFields > 0) ? new ObjectStreamField[numFields] : NO_FIELDS;
        for (int i = 0; i < numFields; i++) {
            char tcode = (char) in.readByte();
            String fname = in.readUTF();
            String signature = ((tcode == 'L') || (tcode == '[')) ? in.readTypeString() : String.valueOf(tcode);
            try {
                fields[i] = new ObjectStreamField(fname, signature, false);
            } catch (RuntimeException e) {
                throw (IOException) new InvalidClassException(name, "invalid descriptor for field " + fname).initCause(e);
            }
        }
        computeFieldOffsets();
    }
    public String getName() { return name; }
    public long getSerialVersionUID() {
        if (suid == null) suid = Long.valueOf(computeDefaultSUID(cl));
        return suid.longValue();
    }
    public Class<?> forClass() { return cl; }
    public ObjectStreamField[] getFields() { return fields.clone(); }
    ObjectStreamField[] getFieldsInternal() { return fields; }
    public ObjectStreamField getField(String name) {
        for (ObjectStreamField f : fields) if (f.getName().equals(name)) return f;
        return null;
    }
    public String toString() { return name + ": static final long serialVersionUID = " + getSerialVersionUID() + "L;"; }
    boolean isProxy() { return isProxy; }
    boolean isEnum() { return isEnum; }
    boolean isRecord() { return isRecord; }
    boolean isExternalizable() { return externalizable; }
    boolean isSerializable() { return serializable; }
    boolean hasBlockExternalData() { return hasBlockExternalData; }
    boolean hasWriteObjectData() { return hasWriteObjectData; }
    boolean hasWriteObjectMethod() { return writeObjectMethod != null; }
    boolean hasReadObjectMethod() { return readObjectMethod != null; }
    boolean hasReadObjectNoDataMethod() { return readObjectNoDataMethod != null; }
    boolean hasWriteReplaceMethod() { return writeReplaceMethod != null; }
    boolean hasReadResolveMethod() { return readResolveMethod != null; }
    ObjectStreamClass getSuperDesc() { return superDesc; }
    ObjectStreamClass getLocalDesc() { return localDesc; }
    Constructor<?> getCons() { return cons; }
    boolean isInstantiable() { return cons != null; }

    Object newInstance() throws InstantiationException, InvocationTargetException {
        if (cons == null) throw new UnsupportedOperationException();
        try {
            if (externalizable) return cons.newInstance();
            Object o = java.lang.VM.allocate(cl);
            java.lang.VM.invoke0(cons.getDeclaringClass(), consSlot(cons), o, new Object[0]);
            return o;
        } catch (IllegalAccessException ex) {
            throw new InternalError(ex.toString());
        } catch (InstantiationException | InvocationTargetException e) { throw e; }
        catch (Throwable t) { throw new InvocationTargetException(t); }
    }
    private static int consSlot(Constructor<?> c) { return c.slot(); }
    void invokeWriteObject(Object obj, ObjectOutputStream out) throws IOException, UnsupportedOperationException {
        try {
            writeObjectMethod.invoke(obj, new Object[]{out});
        } catch (InvocationTargetException ex) {
            Throwable th = ex.getCause();
            if (th instanceof IOException) throw (IOException) th;
            throwMiscException(th);
        } catch (IllegalAccessException ex) { throw new InternalError(ex.toString()); }
    }
    void invokeReadObject(Object obj, ObjectInputStream in) throws ClassNotFoundException, IOException {
        try {
            readObjectMethod.invoke(obj, new Object[]{in});
        } catch (InvocationTargetException ex) {
            Throwable th = ex.getCause();
            if (th instanceof ClassNotFoundException) throw (ClassNotFoundException) th;
            else if (th instanceof IOException) throw (IOException) th;
            else throwMiscException(th);
        } catch (IllegalAccessException ex) { throw new InternalError(ex.toString()); }
    }
    void invokeReadObjectNoData(Object obj) throws IOException {
        try { readObjectNoDataMethod.invoke(obj, (Object[]) null); }
        catch (InvocationTargetException ex) {
            Throwable th = ex.getCause();
            if (th instanceof ObjectStreamException) throw (ObjectStreamException) th;
            else throwMiscException(th);
        } catch (IllegalAccessException ex) { throw new InternalError(ex.toString()); }
    }
    Object invokeWriteReplace(Object obj) throws IOException {
        try { return writeReplaceMethod.invoke(obj, (Object[]) null); }
        catch (InvocationTargetException ex) {
            Throwable th = ex.getCause();
            if (th instanceof ObjectStreamException) throw (ObjectStreamException) th;
            else { throwMiscException(th); throw new InternalError(th); }
        } catch (IllegalAccessException ex) { throw new InternalError(ex.toString()); }
    }
    Object invokeReadResolve(Object obj) throws IOException {
        try { return readResolveMethod.invoke(obj, (Object[]) null); }
        catch (InvocationTargetException ex) {
            Throwable th = ex.getCause();
            if (th instanceof ObjectStreamException) throw (ObjectStreamException) th;
            else { throwMiscException(th); throw new InternalError(th); }
        } catch (IllegalAccessException ex) { throw new InternalError(ex.toString()); }
    }
    private static void throwMiscException(Throwable th) throws IOException {
        if (th instanceof RuntimeException) throw (RuntimeException) th;
        else if (th instanceof Error) throw (Error) th;
        else {
            IOException ex = new IOException("unexpected exception type");
            ex.initCause(th);
            throw ex;
        }
    }
    /** classes de la hierarchie serialisable, de la plus haute a la plus basse */
    ObjectStreamClass[] getLayout() {
        ArrayList<ObjectStreamClass> l = new ArrayList<>();
        for (ObjectStreamClass d = this; d != null; d = d.superDesc) l.add(0, d);
        return l.toArray(new ObjectStreamClass[0]);
    }
    Field[] getFieldRefs() { return fieldRefs; }
    Field fieldFor(ObjectStreamField f) {
        Field fl = f.getField();
        if (fl != null) fl.setAccessible(true);
        return fl;
    }

    // ----- statiques ---------------------------------------------------------
    private static Long getDeclaredSUID(Class<?> cl) {
        try {
            Field f = cl.getDeclaredField("serialVersionUID");
            int mask = Modifier.STATIC | Modifier.FINAL;
            if ((f.getModifiers() & mask) == mask) {
                f.setAccessible(true);
                return Long.valueOf(f.getLong(null));
            }
        } catch (Exception ex) { }
        return null;
    }
    private static ObjectStreamField[] getSerialFields(Class<?> cl) throws InvalidClassException {
        ObjectStreamField[] fields;
        if (Serializable.class.isAssignableFrom(cl) && !Externalizable.class.isAssignableFrom(cl) && !Proxy.isProxyClass(cl) && !cl.isInterface()) {
            if ((fields = getDeclaredSerialFields(cl)) == null) fields = getDefaultSerialFields(cl);
            Arrays.sort(fields);
        } else fields = NO_FIELDS;
        return fields;
    }
    private static ObjectStreamField[] getDeclaredSerialFields(Class<?> cl) throws InvalidClassException {
        ObjectStreamField[] serialPersistentFields = null;
        try {
            Field f = cl.getDeclaredField("serialPersistentFields");
            int mask = Modifier.PRIVATE | Modifier.STATIC | Modifier.FINAL;
            if ((f.getModifiers() & mask) == mask) {
                f.setAccessible(true);
                serialPersistentFields = (ObjectStreamField[]) f.get(null);
            }
        } catch (Exception ex) { }
        if (serialPersistentFields == null) return null;
        else if (serialPersistentFields.length == 0) return NO_FIELDS;
        ObjectStreamField[] boundFields = new ObjectStreamField[serialPersistentFields.length];
        for (int i = 0; i < serialPersistentFields.length; i++) {
            ObjectStreamField spf = serialPersistentFields[i];
            Field f = null;
            try {
                f = cl.getDeclaredField(spf.getName());
                if ((f.getType() == spf.getType()) && ((f.getModifiers() & Modifier.STATIC) == 0)) boundFields[i] = new ObjectStreamField(f, spf.isUnshared(), true);
            } catch (NoSuchFieldException ex) { }
            if (boundFields[i] == null) boundFields[i] = new ObjectStreamField(spf.getName(), spf.getType(), spf.isUnshared());
        }
        return boundFields;
    }
    private static ObjectStreamField[] getDefaultSerialFields(Class<?> cl) {
        Field[] clFields = cl.getDeclaredFields();
        ArrayList<ObjectStreamField> list = new ArrayList<>();
        int mask = Modifier.STATIC | Modifier.TRANSIENT;
        for (int i = 0; i < clFields.length; i++) {
            if ((clFields[i].getModifiers() & mask) == 0 && !clFields[i].isSynthetic()) list.add(new ObjectStreamField(clFields[i], false, true));
        }
        int size = list.size();
        return (size == 0) ? NO_FIELDS : list.toArray(new ObjectStreamField[size]);
    }
    private static Constructor<?> getExternalizableConstructor(Class<?> cl) {
        try {
            Constructor<?> cons = cl.getDeclaredConstructor((Class<?>[]) null);
            cons.setAccessible(true);
            return ((cons.getModifiers() & Modifier.PUBLIC) != 0) ? cons : null;
        } catch (NoSuchMethodException ex) { return null; }
    }
    private static Constructor<?> getSerializableConstructor(Class<?> cl) {
        Class<?> initCl = cl;
        while (Serializable.class.isAssignableFrom(initCl)) {
            if ((initCl = initCl.getSuperclass()) == null) return null;
        }
        try {
            Constructor<?> cons = initCl.getDeclaredConstructor((Class<?>[]) null);
            int mods = cons.getModifiers();
            if ((mods & Modifier.PRIVATE) != 0 || ((mods & (Modifier.PUBLIC | Modifier.PROTECTED)) == 0 && !packageEquals(cl, initCl))) return null;
            cons.setAccessible(true);
            return cons;
        } catch (NoSuchMethodException ex) { return null; }
    }
    private static boolean packageEquals(Class<?> a, Class<?> b) { return a.getPackageName().equals(b.getPackageName()); }
    private static Method getInheritableMethod(Class<?> cl, String name, Class<?>[] argTypes, Class<?> returnType) {
        Method meth = null;
        Class<?> defCl = cl;
        while (defCl != null) {
            try {
                meth = defCl.getDeclaredMethod(name, argTypes);
                break;
            } catch (NoSuchMethodException ex) { defCl = defCl.getSuperclass(); }
        }
        if ((meth == null) || (meth.getReturnType() != returnType)) return null;
        meth.setAccessible(true);
        int mods = meth.getModifiers();
        if ((mods & (Modifier.STATIC | Modifier.ABSTRACT)) != 0) return null;
        else if ((mods & (Modifier.PUBLIC | Modifier.PROTECTED)) != 0) return meth;
        else if ((mods & Modifier.PRIVATE) != 0) return (cl == defCl) ? meth : null;
        else return packageEquals(cl, defCl) ? meth : null;
    }
    private static Method getPrivateMethod(Class<?> cl, String name, Class<?>[] argTypes, Class<?> returnType) {
        try {
            Method meth = cl.getDeclaredMethod(name, argTypes);
            meth.setAccessible(true);
            int mods = meth.getModifiers();
            return ((meth.getReturnType() == returnType) && ((mods & Modifier.STATIC) == 0) && ((mods & Modifier.PRIVATE) != 0)) ? meth : null;
        } catch (NoSuchMethodException ex) { return null; }
    }
    private static boolean hasStaticInitializer(Class<?> cl) {
        int n = java.lang.VM.memberCount(cl, 1);
        for (int i = 0; i < n; i++) if (java.lang.VM.memberName(cl, 1, i).equals("<clinit>")) return true;
        return false;
    }
    private static class MemberSig implements Comparable<MemberSig> {
        final String name, sig;
        final int mods;
        MemberSig(String name, int mods, String sig) { this.name = name; this.mods = mods; this.sig = sig; }
        public int compareTo(MemberSig o) {
            int c = name.compareTo(o.name);
            return c != 0 ? c : sig.compareTo(o.sig);
        }
    }
    private static long computeDefaultSUID(Class<?> cl) {
        if (!Serializable.class.isAssignableFrom(cl) || Proxy.isProxyClass(cl)) return 0L;
        try {
            ByteArrayOutputStream bout = new ByteArrayOutputStream();
            DataOutputStream dout = new DataOutputStream(bout);
            dout.writeUTF(cl.getName());
            int classMods = cl.getModifiers() & (Modifier.PUBLIC | Modifier.FINAL | Modifier.INTERFACE | Modifier.ABSTRACT);
            Method[] methods = cl.getDeclaredMethods();
            if ((classMods & Modifier.INTERFACE) != 0) classMods = (methods.length > 0) ? (classMods | Modifier.ABSTRACT) : (classMods & ~Modifier.ABSTRACT);
            dout.writeInt(classMods);
            if (!cl.isArray()) {
                Class<?>[] interfaces = cl.getInterfaces();
                String[] ifaceNames = new String[interfaces.length];
                for (int i = 0; i < interfaces.length; i++) ifaceNames[i] = interfaces[i].getName();
                Arrays.sort(ifaceNames);
                for (int i = 0; i < ifaceNames.length; i++) dout.writeUTF(ifaceNames[i]);
            }
            Field[] fields = cl.getDeclaredFields();
            MemberSig[] fieldSigs = new MemberSig[fields.length];
            for (int i = 0; i < fields.length; i++) fieldSigs[i] = new MemberSig(fields[i].getName(), fields[i].getModifiers(), fields[i].getType().descriptorString());
            Arrays.sort(fieldSigs);
            for (int i = 0; i < fieldSigs.length; i++) {
                MemberSig sig = fieldSigs[i];
                int mods = sig.mods & (Modifier.PUBLIC | Modifier.PRIVATE | Modifier.PROTECTED | Modifier.STATIC | Modifier.FINAL | Modifier.VOLATILE | Modifier.TRANSIENT);
                if (((mods & Modifier.PRIVATE) == 0) || ((mods & (Modifier.STATIC | Modifier.TRANSIENT)) == 0)) {
                    dout.writeUTF(sig.name);
                    dout.writeInt(mods);
                    dout.writeUTF(sig.sig);
                }
            }
            if (hasStaticInitializer(cl)) {
                dout.writeUTF("<clinit>");
                dout.writeInt(Modifier.STATIC);
                dout.writeUTF("()V");
            }
            Constructor<?>[] cons = cl.getDeclaredConstructors();
            MemberSig[] consSigs = new MemberSig[cons.length];
            for (int i = 0; i < cons.length; i++) consSigs[i] = new MemberSig("<init>", cons[i].getModifiers(), descOf(cons[i].getParameterTypes(), void.class));
            Arrays.sort(consSigs);
            for (int i = 0; i < consSigs.length; i++) {
                MemberSig sig = consSigs[i];
                int mods = sig.mods & (Modifier.PUBLIC | Modifier.PRIVATE | Modifier.PROTECTED | Modifier.STATIC | Modifier.FINAL | Modifier.SYNCHRONIZED | Modifier.NATIVE | Modifier.ABSTRACT | Modifier.STRICT);
                if ((mods & Modifier.PRIVATE) == 0) {
                    dout.writeUTF("<init>");
                    dout.writeInt(mods);
                    dout.writeUTF(sig.sig.replace('/', '.'));
                }
            }
            MemberSig[] methSigs = new MemberSig[methods.length];
            for (int i = 0; i < methods.length; i++) methSigs[i] = new MemberSig(methods[i].getName(), methods[i].getModifiers(), descOf(methods[i].getParameterTypes(), methods[i].getReturnType()));
            Arrays.sort(methSigs);
            for (int i = 0; i < methSigs.length; i++) {
                MemberSig sig = methSigs[i];
                int mods = sig.mods & (Modifier.PUBLIC | Modifier.PRIVATE | Modifier.PROTECTED | Modifier.STATIC | Modifier.FINAL | Modifier.SYNCHRONIZED | Modifier.NATIVE | Modifier.ABSTRACT | Modifier.STRICT);
                if ((mods & Modifier.PRIVATE) == 0) {
                    dout.writeUTF(sig.name);
                    dout.writeInt(mods);
                    dout.writeUTF(sig.sig.replace('/', '.'));
                }
            }
            dout.flush();
            byte[] hashBytes = Sha1.digest(bout.toByteArray());
            long hash = 0;
            for (int i = Math.min(hashBytes.length, 8) - 1; i >= 0; i--) hash = (hash << 8) | (hashBytes[i] & 0xFF);
            return hash;
        } catch (IOException ex) {
            throw new InternalError(ex);
        }
    }
    private static String descOf(Class<?>[] ps, Class<?> r) {
        StringBuilder sb = new StringBuilder("(");
        for (Class<?> p : ps) sb.append(p.descriptorString());
        return sb.append(')').append(r.descriptorString()).toString();
    }
}
