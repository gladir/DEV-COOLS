package java.lang.reflect;
import java.lang.annotation.Annotation;
final class AnnotatedWildcardTypeImpl extends AnnotatedTypeImpl implements AnnotatedWildcardType {
    private final AnnotatedType[] up, low;
    AnnotatedWildcardTypeImpl(Type type, Annotation[] annos, AnnotatedType[] up, AnnotatedType[] low) { super(type, annos); this.up = up; this.low = low; }
    public AnnotatedType[] getAnnotatedUpperBounds() { return up.clone(); }
    public AnnotatedType[] getAnnotatedLowerBounds() { return low.clone(); }
}
