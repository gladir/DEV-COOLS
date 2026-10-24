import java.lang.annotation.*;
import java.lang.reflect.*;
import java.util.*;

@Retention(RetentionPolicy.RUNTIME) @Target(ElementType.TYPE_USE) @interface TU { int value() default 0; }
@Retention(RetentionPolicy.RUNTIME) @Target({ElementType.TYPE_USE, ElementType.FIELD, ElementType.METHOD, ElementType.PARAMETER}) @interface Both { }

public class Test17_TypeUse {
    @TU(1) String f;
    @TU(2) String[] arr;
    @Both int g;
    @TU(3) List<String> lst;
    class In {}
    @TU(5) In in;
    @TU(6) String m(@TU(7) int a, @Both String b) { return null; }
    @TU(8) Test17_TypeUse() {}
    public static void main(String[] args) throws Exception {
        Class<?> c = Test17_TypeUse.class;
        for (String n : new String[]{"f", "arr", "g", "lst", "in"}) {
            Field fl = c.getDeclaredField(n);
            System.out.println(n + " " + fl.getAnnotatedType() + " | " + Arrays.toString(fl.getAnnotations()));
        }
        Method m = c.getDeclaredMethod("m", int.class, String.class);
        System.out.println(m.getAnnotatedReturnType());
        for (AnnotatedType t : m.getAnnotatedParameterTypes()) System.out.println(t);
        System.out.println(Arrays.toString(m.getAnnotations()));
        System.out.println(c.getDeclaredConstructor().getAnnotatedReturnType());
    }
}
