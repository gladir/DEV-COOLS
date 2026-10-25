package java.lang.reflect;
import java.util.Arrays;
final class ParameterizedTypeImpl implements ParameterizedType {
    private final Type[] actual;
    private final Class<?> raw;
    private final Type owner;
    ParameterizedTypeImpl(Class<?> raw, Type[] actual, Type owner) {
        this.raw = raw; this.actual = actual;
        this.owner = (owner != null) ? owner : raw.getDeclaringClass();
    }
    public Type[] getActualTypeArguments() { return actual.clone(); }
    public Class<?> getRawType() { return raw; }
    public Type getOwnerType() { return owner; }
    public boolean equals(Object o) {
        if (o instanceof ParameterizedType) {
            ParameterizedType that = (ParameterizedType) o;
            if (this == that) return true;
            return java.util.Objects.equals(owner, that.getOwnerType()) && java.util.Objects.equals(raw, that.getRawType())
                && Arrays.equals(actual, that.getActualTypeArguments());
        }
        return false;
    }
    public int hashCode() { return Arrays.hashCode(actual) ^ java.util.Objects.hashCode(owner) ^ java.util.Objects.hashCode(raw); }
    public String toString() {
        StringBuilder sb = new StringBuilder();
        if (owner != null) {
            sb.append(owner.getTypeName());
            sb.append("$");
            if (owner instanceof ParameterizedTypeImpl) {
                sb.append(raw.getName().replace(((Class<?>) ((ParameterizedTypeImpl) owner).raw).getName() + "$", ""));
            } else sb.append(raw.getSimpleName());
        } else sb.append(raw.getName());
        if (actual != null && actual.length > 0) {
            sb.append('<');
            for (int i = 0; i < actual.length; i++) {
                if (i > 0) sb.append(", ");
                sb.append(actual[i].getTypeName());
            }
            sb.append('>');
        }
        return sb.toString();
    }
}
