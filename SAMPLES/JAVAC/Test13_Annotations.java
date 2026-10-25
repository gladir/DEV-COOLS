import java.lang.annotation.*;
import java.lang.reflect.*;
import java.util.*;

@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD, ElementType.FIELD, ElementType.PARAMETER, ElementType.CONSTRUCTOR})
@interface Info {
    String name() default "none";
    int level() default 1;
    long big() default 5000000000L;
    double d() default 1.5;
    float f() default 2.5f;
    boolean flag() default true;
    char c() default 'x';
    byte b() default 7;
    short s() default 300;
    String[] tags() default {};
    int[] nums() default {1, 2, 3};
    Class<?> type() default Object.class;
    Class<?>[] types() default {};
    RetentionPolicy pol() default RetentionPolicy.CLASS;
    Sub sub() default @Sub(5);
    Sub[] subs() default {};
}

@Retention(RetentionPolicy.RUNTIME)
@interface Sub { int value(); }

@Retention(RetentionPolicy.CLASS)
@interface Invisible { String value() default "inv"; }

@Retention(RetentionPolicy.RUNTIME)
@Repeatable(Tags.class)
@interface Tag { String value(); }

@Retention(RetentionPolicy.RUNTIME)
@interface Tags { Tag[] value(); }

@Info(name = "main", level = 3, tags = {"a", "b"}, type = String.class, types = {int.class, String[].class},
      pol = RetentionPolicy.RUNTIME, sub = @Sub(9), subs = {@Sub(1), @Sub(2)})
@Invisible
@Tag("one") @Tag("two")
@Deprecated
public class Test13_Annotations {
    static final String K = "const" + 1;

    @Info(name = K, nums = 42) public int field;
    @Deprecated(since = "9", forRemoval = true) public int old;

    @Info @FunctionalInterface interface F { void f(); }

    @Info(level = 7)
    public Test13_Annotations(@Sub(1) int a, int b, @Info(name = "p") @Sub(3) String c) {}

    @Override public String toString() { return "Test13_Annotations"; }

    @Info(f = 1f, d = 2, b = 1, s = 2, c = 'q', big = 1)
    public void m(@Sub(10) int x, @Invisible("zz") int y) {}

    enum E { @Info(name = "enumconst") X, Y }

    record R(@Sub(4) int a, @Info(name="rc") String b) {}

    static String show(Annotation a) { return a.toString().replace("Test13_Annotations.", ""); }

    public static void main(String[] args) throws Exception {
        Class<?> c = Test13_Annotations.class;
        System.out.println(Arrays.toString(c.getAnnotations()).replace("Test13_Annotations.", ""));
        System.out.println(show(c.getField("field").getAnnotation(Info.class)));
        System.out.println(Arrays.toString(c.getField("old").getAnnotations()));
        Constructor<?> k = c.getConstructors()[0];
        System.out.println(show(k.getAnnotation(Info.class)));
        for (Annotation[] pa : k.getParameterAnnotations()) System.out.println(Arrays.toString(pa).replace("Test13_Annotations.", ""));
        Method m = c.getMethod("m", int.class, int.class);
        System.out.println(show(m.getAnnotation(Info.class)));
        for (Annotation[] pa : m.getParameterAnnotations()) System.out.println(Arrays.toString(pa).replace("Test13_Annotations.", ""));
        System.out.println(Arrays.toString(E.class.getField("X").getAnnotations()).replace("Test13_Annotations.", ""));
        System.out.println(F.class.isAnnotationPresent(FunctionalInterface.class));
        System.out.println(Info.class.getMethod("level").getDefaultValue());
        System.out.println(Arrays.toString((int[]) Info.class.getMethod("nums").getDefaultValue()));
        System.out.println(Info.class.getMethod("sub").getDefaultValue().toString().replace("Test13_Annotations.", ""));
        System.out.println(Arrays.toString(R.class.getRecordComponents()).replace("Test13_Annotations.", ""));
        for (RecordComponent rc : R.class.getRecordComponents()) System.out.println(Arrays.toString(rc.getAnnotations()).replace("Test13_Annotations.", ""));
        System.out.println(Arrays.toString(R.class.getDeclaredField("a").getAnnotations()).replace("Test13_Annotations.", ""));
        System.out.println(Arrays.toString(R.class.getMethod("a").getAnnotations()).replace("Test13_Annotations.", ""));
        System.out.println(Arrays.toString(R.class.getDeclaredConstructors()[0].getParameterAnnotations()[0]).replace("Test13_Annotations.", ""));
        System.out.println(Arrays.toString(c.getAnnotationsByType(Tag.class)).replace("Test13_Annotations.", ""));
    }
}
