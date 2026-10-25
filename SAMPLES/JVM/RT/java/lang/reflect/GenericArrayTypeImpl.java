package java.lang.reflect;
final class GenericArrayTypeImpl implements GenericArrayType {
    private final Type comp;
    GenericArrayTypeImpl(Type comp) { this.comp = comp; }
    public Type getGenericComponentType() { return comp; }
    public String toString() { return comp.getTypeName() + "[]"; }
    public boolean equals(Object o) {
        if (o instanceof GenericArrayType) return java.util.Objects.equals(comp, ((GenericArrayType) o).getGenericComponentType());
        return false;
    }
    public int hashCode() { return java.util.Objects.hashCode(comp); }
}
