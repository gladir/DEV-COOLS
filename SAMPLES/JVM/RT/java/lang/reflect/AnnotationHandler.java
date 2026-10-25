package java.lang.reflect;
import java.lang.annotation.Annotation;
import java.lang.annotation.IncompleteAnnotationException;
import java.util.Arrays;
import java.util.Map;
final class AnnotationHandler implements InvocationHandler, java.io.Serializable {
    private final Class<? extends Annotation> type;
    private final Map<String, Object> values;
    AnnotationHandler(Class<?> type, Map<String, Object> values) {
        this.type = (Class<? extends Annotation>) type;
        this.values = values;
    }
    public Object invoke(Object proxy, Method method, Object[] args) {
        String member = method.getName();
        int parameterCount = method.getParameterCount();
        if (parameterCount == 1 && member.equals("equals") && method.getParameterTypes()[0] == Object.class) return equalsImpl(proxy, args[0]);
        if (parameterCount != 0) throw new AssertionError("Too many parameters for an annotation method");
        if (member.equals("toString")) return toStringImpl();
        if (member.equals("hashCode")) return hashCodeImpl();
        if (member.equals("annotationType")) return type;
        Object result = values.get(member);
        if (result == null) throw new IncompleteAnnotationException(type, member);
        if (result.getClass().isArray() && Array.getLength(result) != 0) result = cloneArray(result);
        return result;
    }
    private Object cloneArray(Object a) {
        if (a instanceof Object[]) return ((Object[]) a).clone();
        if (a instanceof int[]) return ((int[]) a).clone();
        if (a instanceof long[]) return ((long[]) a).clone();
        if (a instanceof double[]) return ((double[]) a).clone();
        if (a instanceof float[]) return ((float[]) a).clone();
        if (a instanceof char[]) return ((char[]) a).clone();
        if (a instanceof byte[]) return ((byte[]) a).clone();
        if (a instanceof short[]) return ((short[]) a).clone();
        return ((boolean[]) a).clone();
    }
    private String toStringImpl() {
        StringBuilder result = new StringBuilder(128);
        result.append('@');
        String cn = type.getCanonicalName();
        result.append(cn == null ? "<no canonical name>" : cn);
        result.append('(');
        boolean firstMember = true;
        boolean loneValue = values.size() == 1;
        for (Map.Entry<String, Object> e : values.entrySet()) {
            if (firstMember) firstMember = false; else result.append(", ");
            String key = e.getKey();
            if (!loneValue || !"value".equals(key)) {
                result.append(key);
                result.append('=');
            }
            loneValue = false;
            result.append(memberValueToString(e.getValue()));
        }
        result.append(')');
        return result.toString();
    }
    private static String memberValueToString(Object value) {
        Class<?> type = value.getClass();
        if (!type.isArray()) {
            if (type == Class.class) return toSourceString((Class<?>) value);
            else if (type == String.class) return toSourceString((String) value);
            if (type == Character.class) return toSourceString((char) (Character) value);
            else if (type == Double.class) return toSourceString((double) (Double) value);
            else if (type == Float.class) return toSourceString((float) (Float) value);
            else if (type == Long.class) return toSourceString((long) (Long) value);
            else if (type == Byte.class) return toSourceString((byte) (Byte) value);
            else if (value instanceof Enum) return ((Enum<?>) value).name();
            else return value.toString();
        } else {
            StringBuilder sb = new StringBuilder("{");
            int n = Array.getLength(value);
            for (int i = 0; i < n; i++) {
                if (i > 0) sb.append(", ");
                sb.append(memberValueToString(Array.get(value, i)));
            }
            sb.append('}');
            return sb.toString();
        }
    }
    private static String toSourceString(Class<?> clazz) {
        Class<?> finalComponent = clazz;
        StringBuilder arrayBrackets = new StringBuilder();
        while (finalComponent.isArray()) {
            finalComponent = finalComponent.getComponentType();
            arrayBrackets.append("[]");
        }
        return finalComponent.getName() + arrayBrackets.toString() + ".class";
    }
    private static String toSourceString(float f) {
        if (Float.isFinite(f)) return Float.toString(f) + "f";
        if (Float.isInfinite(f)) return (f < 0.0f) ? "-1.0f/0.0f" : "1.0f/0.0f";
        return "0.0f/0.0f";
    }
    private static String toSourceString(double d) {
        if (Double.isFinite(d)) return Double.toString(d);
        if (Double.isInfinite(d)) return (d < 0.0f) ? "-1.0/0.0" : "1.0/0.0";
        return "0.0/0.0";
    }
    private static String toSourceString(char c) {
        StringBuilder sb = new StringBuilder(4);
        sb.append('\'');
        sb.append(quote(c));
        return sb.append('\'').toString();
    }
    private static String quote(char ch) {
        switch (ch) {
            case '\b': return "\\b";
            case '\f': return "\\f";
            case '\n': return "\\n";
            case '\r': return "\\r";
            case '\t': return "\\t";
            case '\'': return "\\'";
            case '\"': return "\\\"";
            case '\\': return "\\\\";
            default:
                return (ch >= ' ' && ch <= '~') ? String.valueOf(ch) : String.format("\\u%04x", (int) ch);
        }
    }
    private static String toSourceString(long ell) { return String.valueOf(ell) + "L"; }
    private static String toSourceString(byte b) { return String.format("(byte)0x%02x", b); }
    private static String toSourceString(String s) {
        StringBuilder sb = new StringBuilder();
        sb.append('"');
        for (int i = 0; i < s.length(); i++) sb.append(quote(s.charAt(i)));
        sb.append('"');
        return sb.toString();
    }
    private Boolean equalsImpl(Object proxy, Object o) {
        if (o == proxy) return true;
        if (!type.isInstance(o)) return false;
        for (Method memberMethod : type.getDeclaredMethods()) {
            if (Modifier.isStatic(memberMethod.getModifiers()) || memberMethod.getParameterCount() != 0) continue;
            String member = memberMethod.getName();
            Object ourValue = values.get(member);
            Object hisValue = null;
            if (o instanceof Proxy && Proxy.getInvocationHandler(o) instanceof AnnotationHandler) {
                hisValue = ((AnnotationHandler) Proxy.getInvocationHandler(o)).values.get(member);
            } else {
                try { hisValue = memberMethod.invoke(o); } catch (Exception e) { return false; }
            }
            if (!memberValueEquals(ourValue, hisValue)) return false;
        }
        return true;
    }
    private static boolean memberValueEquals(Object v1, Object v2) {
        if (v1 == null || v2 == null) return v1 == v2;
        Class<?> type = v1.getClass();
        if (!type.isArray()) return v1.equals(v2);
        if (v1 instanceof Object[] && v2 instanceof Object[]) return Arrays.equals((Object[]) v1, (Object[]) v2);
        if (v2.getClass() != type) return false;
        if (type == byte[].class) return Arrays.equals((byte[]) v1, (byte[]) v2);
        if (type == char[].class) return Arrays.equals((char[]) v1, (char[]) v2);
        if (type == double[].class) return Arrays.equals((double[]) v1, (double[]) v2);
        if (type == float[].class) return Arrays.equals((float[]) v1, (float[]) v2);
        if (type == int[].class) return Arrays.equals((int[]) v1, (int[]) v2);
        if (type == long[].class) return Arrays.equals((long[]) v1, (long[]) v2);
        if (type == short[].class) return Arrays.equals((short[]) v1, (short[]) v2);
        return Arrays.equals((boolean[]) v1, (boolean[]) v2);
    }
    private int hashCodeImpl() {
        int result = 0;
        for (Map.Entry<String, Object> e : values.entrySet()) result += (127 * e.getKey().hashCode()) ^ memberValueHashCode(e.getValue());
        return result;
    }
    private static int memberValueHashCode(Object value) {
        Class<?> type = value.getClass();
        if (!type.isArray()) return value.hashCode();
        if (type == byte[].class) return Arrays.hashCode((byte[]) value);
        if (type == char[].class) return Arrays.hashCode((char[]) value);
        if (type == double[].class) return Arrays.hashCode((double[]) value);
        if (type == float[].class) return Arrays.hashCode((float[]) value);
        if (type == int[].class) return Arrays.hashCode((int[]) value);
        if (type == long[].class) return Arrays.hashCode((long[]) value);
        if (type == short[].class) return Arrays.hashCode((short[]) value);
        if (type == boolean[].class) return Arrays.hashCode((boolean[]) value);
        return Arrays.hashCode((Object[]) value);
    }
}
