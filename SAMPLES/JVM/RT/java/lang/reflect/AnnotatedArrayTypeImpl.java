package java.lang.reflect;
import java.lang.annotation.Annotation;
final class AnnotatedArrayTypeImpl extends AnnotatedTypeImpl implements AnnotatedArrayType {
    private final AnnotatedType comp;
    AnnotatedArrayTypeImpl(Type type, Annotation[] annos, AnnotatedType comp) { super(type, annos); this.comp = comp; }
    public AnnotatedType getAnnotatedGenericComponentType() { return comp; }
    public String toString() { return comp.toString() + (annos.length > 0 ? " " + prefix().trim() : "") + "[]"; }
}
