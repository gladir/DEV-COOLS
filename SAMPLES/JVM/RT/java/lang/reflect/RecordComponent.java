package java.lang.reflect;
import java.lang.annotation.Annotation;
public final class RecordComponent implements AnnotatedElement {
    private final Class<?> clazz;
    private final String name;
    private final Class<?> type;
    private final String signature;
    private final byte[] annBytes;
    private final byte[] typeAnnBytes;
    private Annotation[] annos;
    public static RecordComponent make(Class<?> clazz, String name, Class<?> type, String signature, byte[] annBytes, byte[] typeAnnBytes) {
        return new RecordComponent(clazz, name, type, signature, annBytes, typeAnnBytes);
    }
    RecordComponent(Class<?> clazz, String name, Class<?> type, String signature, byte[] annBytes, byte[] typeAnnBytes) {
        this.clazz = clazz; this.name = name; this.type = type; this.signature = signature; this.annBytes = annBytes; this.typeAnnBytes = typeAnnBytes;
    }
    public String getName() { return name; }
    public Class<?> getType() { return type; }
    public String getGenericSignature() { return signature; }
    public Type getGenericType() { return signature == null ? type : Generics.fieldType(signature, clazz); }
    public AnnotatedType getAnnotatedType() { return TypeAnnotations.annotate(getGenericType(), typeAnnBytes, clazz, 0x13, 0); }
    public Method getAccessor() {
        try { return clazz.getDeclaredMethod(name); } catch (NoSuchMethodException e) { return null; }
    }
    public Class<?> getDeclaringRecord() { return clazz; }
    public Annotation[] getDeclaredAnnotations() {
        if (annos == null) annos = AnnotationSupport.parse(annBytes, clazz);
        return annos.clone();
    }
    public Annotation[] getAnnotations() { return getDeclaredAnnotations(); }
    public <T extends Annotation> T getAnnotation(Class<T> annotationClass) {
        for (Annotation a : getDeclaredAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
    public String toString() { return type.getTypeName() + " " + name; }
}
