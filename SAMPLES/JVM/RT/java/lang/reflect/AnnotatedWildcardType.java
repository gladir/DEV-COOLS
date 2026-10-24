package java.lang.reflect;
public interface AnnotatedWildcardType extends AnnotatedType {
    AnnotatedType[] getAnnotatedUpperBounds();
    AnnotatedType[] getAnnotatedLowerBounds();
}
