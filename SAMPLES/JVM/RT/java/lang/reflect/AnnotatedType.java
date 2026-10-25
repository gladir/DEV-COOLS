package java.lang.reflect;
public interface AnnotatedType extends AnnotatedElement {
    Type getType();
    default AnnotatedType getAnnotatedOwnerType() { return null; }
}
