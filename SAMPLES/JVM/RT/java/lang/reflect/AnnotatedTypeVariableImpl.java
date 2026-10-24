package java.lang.reflect;
import java.lang.annotation.Annotation;
final class AnnotatedTypeVariableImpl extends AnnotatedTypeImpl implements AnnotatedTypeVariable {
    AnnotatedTypeVariableImpl(Type type, Annotation[] annos) { super(type, annos); }
    public AnnotatedType[] getAnnotatedBounds() { return ((TypeVariable<?>) type).getAnnotatedBounds(); }
}
