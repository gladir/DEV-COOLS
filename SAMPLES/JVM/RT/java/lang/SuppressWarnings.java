package java.lang;
import java.lang.annotation.*;
@Target({ElementType.TYPE, ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER, ElementType.CONSTRUCTOR, ElementType.LOCAL_VARIABLE, ElementType.MODULE})
@Retention(RetentionPolicy.SOURCE)
public @interface SuppressWarnings { String[] value(); }
