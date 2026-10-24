package java.lang.reflect;
import java.lang.annotation.Annotation;
final class TypeVariableImpl<D extends GenericDeclaration> implements TypeVariable<D> {
    private final D decl;
    private final String name;
    private final String boundSig;
    private Type[] bounds;
    TypeVariableImpl(D decl, String name, String boundSig) { this.decl = decl; this.name = name; this.boundSig = boundSig; }
    public Type[] getBounds() {
        if (bounds == null) bounds = Generics.parseBounds(boundSig, decl);
        return bounds.clone();
    }
    public D getGenericDeclaration() { return decl; }
    public String getName() { return name; }
    public AnnotatedType[] getAnnotatedBounds() {
        Type[] b = getBounds();
        AnnotatedType[] r = new AnnotatedType[b.length];
        for (int i = 0; i < b.length; i++) r[i] = new AnnotatedTypeImpl(b[i], new Annotation[0]);
        return r;
    }
    public String toString() { return name; }
    public boolean equals(Object o) {
        if (o instanceof TypeVariableImpl) {
            TypeVariableImpl<?> t = (TypeVariableImpl<?>) o;
            return name.equals(t.name) && decl.equals(t.decl);
        }
        return false;
    }
    public int hashCode() { return decl.hashCode() ^ name.hashCode(); }
    public <T extends Annotation> T getAnnotation(Class<T> annotationClass) { return null; }
    public Annotation[] getAnnotations() { return new Annotation[0]; }
    public Annotation[] getDeclaredAnnotations() { return new Annotation[0]; }
}
