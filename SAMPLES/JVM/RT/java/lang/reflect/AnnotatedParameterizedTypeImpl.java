package java.lang.reflect;
import java.lang.annotation.Annotation;
final class AnnotatedParameterizedTypeImpl extends AnnotatedTypeImpl implements AnnotatedParameterizedType {
    private final AnnotatedType[] args;
    AnnotatedParameterizedTypeImpl(Type type, Annotation[] annos, AnnotatedType[] args) { super(type, annos); this.args = args; }
    public AnnotatedType[] getAnnotatedActualTypeArguments() { return args.clone(); }
    public String toString() {
        ParameterizedType p = (ParameterizedType) type;
        StringBuilder sb = new StringBuilder(prefix());
        Type raw = p.getRawType();
        Type owner = p.getOwnerType();
        sb.append(raw.getTypeName());
        sb.append('<');
        for (int i = 0; i < args.length; i++) {
            if (i > 0) sb.append(", ");
            sb.append(args[i].toString());
        }
        sb.append('>');
        return sb.toString();
    }
}
