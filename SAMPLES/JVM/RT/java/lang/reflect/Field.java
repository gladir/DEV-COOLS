package java.lang.reflect;
import java.lang.annotation.Annotation;
public final class Field extends AccessibleObject implements Member {
    Class<?> clazz;
    int slot;
    String name;
    Class<?> type;
    int modifiers;
    private Annotation[] annos;
    Field(Class<?> clazz, int slot, String name, Class<?> type, int modifiers) {
        this.clazz = clazz; this.slot = slot; this.name = name; this.type = type; this.modifiers = modifiers;
    }
    public static Field make(Class<?> c, int slot) {
        return new Field(c, slot, VM.memberName(c, 0, slot), VM.classOfDescOrThrow(VM.memberDesc(c, 0, slot)), VM.memberFlags(c, 0, slot));
    }
    public Class<?> getDeclaringClass() { return clazz; }
    public String getName() { return name; }
    public int getModifiers() { return modifiers; }
    public boolean isEnumConstant() { return (modifiers & 0x4000) != 0; }
    public boolean isSynthetic() { return (modifiers & 0x1000) != 0; }
    public Class<?> getType() { return type; }
    byte[] attr(String n) { return VM.memberAttr(clazz, 0, slot, n); }
    public Type getGenericType() {
        byte[] b = attr("Signature");
        if (b == null) return type;
        String sig = VM.cpUtf8(clazz, ((b[0] & 255) << 8) | (b[1] & 255));
        return Generics.fieldType(sig, clazz);
    }
    public AnnotatedType getAnnotatedType() {
        return TypeAnnotations.annotate(getGenericType(), attr("RuntimeVisibleTypeAnnotations"), clazz, 0x13, 0);
    }
    public Annotation[] getDeclaredAnnotations() {
        if (annos == null) annos = AnnotationSupport.parse(attr("RuntimeVisibleAnnotations"), clazz);
        return annos.clone();
    }
    public Annotation[] getAnnotations() { return getDeclaredAnnotations(); }
    public <T extends Annotation> T getAnnotation(Class<T> annotationClass) {
        if (annotationClass == null) throw new NullPointerException();
        for (Annotation a : getDeclaredAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
    private void check(Object obj, String what) throws IllegalAccessException {
        if (!override && (modifiers & Modifier.PUBLIC) == 0) {
            Class<?> caller = AnnotationSupport.callerClass(3);
            if (caller != null) AnnotationSupport.checkMember(caller, clazz, modifiers);
        }
        if ((modifiers & Modifier.STATIC) == 0) {
            if (obj == null) throw new NullPointerException("Cannot invoke \"Object.getClass()\" because \"obj\" is null");
            if (!clazz.isInstance(obj))
                throw new IllegalArgumentException("Can not " + what + " " + type.getTypeName() + " field " + clazz.getTypeName() + "." + name + " on " + obj.getClass().getTypeName());
        }
    }
    public Object get(Object obj) throws IllegalArgumentException, IllegalAccessException {
        check(obj, "get");
        return VM.fieldGet(obj, clazz, slot);
    }
    public void set(Object obj, Object value) throws IllegalArgumentException, IllegalAccessException {
        check(obj, "set");
        if ((modifiers & Modifier.FINAL) != 0 && ((modifiers & Modifier.STATIC) != 0 || !override))
            throw new IllegalAccessException("Can not set " + ((modifiers & Modifier.STATIC) != 0 ? "static " : "") + "final " + type.getTypeName() + " field "
                + clazz.getTypeName() + "." + name + " to " + (value == null ? "null value" : value.getClass().getTypeName()));
        if (type.isPrimitive()) {
            if (value == null || !AnnotationSupport.canConvert(value.getClass(), type))
                throw new IllegalArgumentException("Can not set " + type.getTypeName() + " field " + clazz.getTypeName() + "." + name + " to "
                    + (value == null ? "null value" : value.getClass().getTypeName()));
        } else if (value != null && !type.isInstance(value)) {
            throw new IllegalArgumentException("Can not set " + type.getTypeName() + " field " + clazz.getTypeName() + "." + name + " to " + value.getClass().getTypeName());
        }
        VM.fieldSet(obj, clazz, slot, value);
    }
    private Object getPrim(Object obj, Class<?> want) throws IllegalAccessException {
        Object v = get(obj);
        if (!type.isPrimitive() || !AnnotationSupport.canConvert(type, want))
            throw new IllegalArgumentException("Attempt to get " + type.getTypeName() + " field \"" + clazz.getTypeName() + "." + name + "\" with illegal data type conversion to " + want.getTypeName());
        return v;
    }
    public boolean getBoolean(Object obj) throws IllegalAccessException { return (Boolean) getPrim(obj, boolean.class); }
    public byte getByte(Object obj) throws IllegalAccessException { return (Byte) getPrim(obj, byte.class); }
    public char getChar(Object obj) throws IllegalAccessException { return (Character) getPrim(obj, char.class); }
    public short getShort(Object obj) throws IllegalAccessException { return ((Number) getPrim(obj, short.class)).shortValue(); }
    public int getInt(Object obj) throws IllegalAccessException {
        Object v = getPrim(obj, int.class);
        if (v instanceof Character) return (Character) v;
        return ((Number) v).intValue();
    }
    public long getLong(Object obj) throws IllegalAccessException {
        Object v = getPrim(obj, long.class);
        if (v instanceof Character) return (Character) v;
        return ((Number) v).longValue();
    }
    public float getFloat(Object obj) throws IllegalAccessException {
        Object v = getPrim(obj, float.class);
        if (v instanceof Character) return (Character) v;
        return ((Number) v).floatValue();
    }
    public double getDouble(Object obj) throws IllegalAccessException {
        Object v = getPrim(obj, double.class);
        if (v instanceof Character) return (Character) v;
        return ((Number) v).doubleValue();
    }
    public void setBoolean(Object obj, boolean z) throws IllegalAccessException { set(obj, Boolean.valueOf(z)); }
    public void setByte(Object obj, byte b) throws IllegalAccessException { set(obj, Byte.valueOf(b)); }
    public void setChar(Object obj, char c) throws IllegalAccessException { set(obj, Character.valueOf(c)); }
    public void setShort(Object obj, short s) throws IllegalAccessException { set(obj, Short.valueOf(s)); }
    public void setInt(Object obj, int i) throws IllegalAccessException { set(obj, Integer.valueOf(i)); }
    public void setLong(Object obj, long l) throws IllegalAccessException { set(obj, Long.valueOf(l)); }
    public void setFloat(Object obj, float f) throws IllegalAccessException { set(obj, Float.valueOf(f)); }
    public void setDouble(Object obj, double d) throws IllegalAccessException { set(obj, Double.valueOf(d)); }
    public String toString() {
        int mod = getModifiers();
        return ((mod == 0) ? "" : (Modifier.toString(mod & Modifier.fieldModifiers()) + (((mod & Modifier.fieldModifiers()) != 0) ? " " : "")))
            + type.getTypeName() + " " + clazz.getTypeName() + "." + name;
    }
    public String toGenericString() {
        int mod = getModifiers();
        return ((mod == 0) ? "" : (Modifier.toString(mod & Modifier.fieldModifiers()) + (((mod & Modifier.fieldModifiers()) != 0) ? " " : "")))
            + getGenericType().getTypeName() + " " + clazz.getTypeName() + "." + name;
    }
    public boolean equals(Object obj) {
        if (obj instanceof Field) {
            Field o = (Field) obj;
            return clazz == o.clazz && name.equals(o.name) && type == o.type;
        }
        return false;
    }
    public int hashCode() { return clazz.getName().hashCode() ^ name.hashCode(); }
    public Field copy() {
        Field f = new Field(clazz, slot, name, type, modifiers);
        f.override = override;
        return f;
    }
}
