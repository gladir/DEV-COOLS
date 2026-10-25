package java.lang.reflect;
import java.lang.annotation.Annotation;
import java.lang.annotation.Repeatable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
public interface AnnotatedElement {
    default boolean isAnnotationPresent(Class<? extends Annotation> annotationClass) {
        return getAnnotation(annotationClass) != null;
    }
    <T extends Annotation> T getAnnotation(Class<T> annotationClass);
    Annotation[] getAnnotations();
    default <T extends Annotation> T[] getAnnotationsByType(Class<T> annotationClass) {
        return AnnotationSupport.byType(getAnnotations(), annotationClass);
    }
    default <T extends Annotation> T getDeclaredAnnotation(Class<T> annotationClass) {
        for (Annotation a : getDeclaredAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
    default <T extends Annotation> T[] getDeclaredAnnotationsByType(Class<T> annotationClass) {
        return AnnotationSupport.byType(getDeclaredAnnotations(), annotationClass);
    }
    Annotation[] getDeclaredAnnotations();
}
