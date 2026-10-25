package java.lang;
import java.lang.annotation.*;
@Documented @Retention(RetentionPolicy.RUNTIME)
@Target(value = {ElementType.CONSTRUCTOR, ElementType.FIELD, ElementType.LOCAL_VARIABLE, ElementType.METHOD, ElementType.PACKAGE, ElementType.MODULE, ElementType.PARAMETER, ElementType.TYPE})
public @interface Deprecated {
    String since() default "";
    boolean forRemoval() default false;
}
