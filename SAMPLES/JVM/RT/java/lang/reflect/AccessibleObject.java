package java.lang.reflect;
import java.lang.annotation.Annotation;
public class AccessibleObject implements AnnotatedElement {
    boolean override;
    protected AccessibleObject() {}
    public static void setAccessible(AccessibleObject[] array, boolean flag) {
        for (AccessibleObject a : array) a.setAccessible(flag);
    }
    public void setAccessible(boolean flag) { override = flag; }
    public final boolean trySetAccessible() { override = true; return true; }
    @Deprecated public boolean isAccessible() { return override; }
    public final boolean canAccess(Object obj) { return true; }
    public <T extends Annotation> T getAnnotation(Class<T> annotationClass) { return null; }
    public boolean isAnnotationPresent(Class<? extends Annotation> annotationClass) { return getAnnotation(annotationClass) != null; }
    public Annotation[] getAnnotations() { return getDeclaredAnnotations(); }
    public Annotation[] getDeclaredAnnotations() { return new Annotation[0]; }
}
