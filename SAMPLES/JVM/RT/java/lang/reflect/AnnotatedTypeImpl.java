package java.lang.reflect;
import java.lang.annotation.Annotation;
class AnnotatedTypeImpl implements AnnotatedType {
    final Type type;
    final Annotation[] annos;
    AnnotatedTypeImpl(Type type, Annotation[] annos) { this.type = type; this.annos = annos; }
    public Type getType() { return type; }
    public <T extends Annotation> T getAnnotation(Class<T> c) {
        for (Annotation a : annos) if (c.isInstance(a)) return c.cast(a);
        return null;
    }
    public Annotation[] getAnnotations() { return annos.clone(); }
    public Annotation[] getDeclaredAnnotations() { return annos.clone(); }
    String prefix() {
        StringBuilder sb = new StringBuilder();
        for (Annotation a : annos) sb.append(a.toString()).append(' ');
        return sb.toString();
    }
    public String toString() { return prefix() + type.getTypeName(); }
}
