package java.lang.reflect;
public interface TypeVariable<D extends GenericDeclaration> extends Type, AnnotatedElement {
    Type[] getBounds();
    D getGenericDeclaration();
    String getName();
    AnnotatedType[] getAnnotatedBounds();
}
