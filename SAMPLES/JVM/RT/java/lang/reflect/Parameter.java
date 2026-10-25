package java.lang.reflect;
import java.lang.annotation.Annotation;
public final class Parameter implements AnnotatedElement {
    private final String name;
    private final int modifiers;
    private final Executable executable;
    private final int index;
    private final boolean present;
    Parameter(String name, int modifiers, Executable executable, int index, boolean present) {
        this.name = name; this.modifiers = modifiers; this.executable = executable; this.index = index; this.present = present;
    }
    public boolean isNamePresent() { return present; }
    public String getName() { return name; }
    public int getModifiers() { return modifiers; }
    public Executable getDeclaringExecutable() { return executable; }
    public Class<?> getType() { return executable.ptypes[index]; }
    public Type getParameterizedType() {
        Type[] t = executable.getGenericParameterTypes();
        return t[index];
    }
    public boolean isVarArgs() { return executable.isVarArgs() && index == executable.ptypes.length - 1; }
    public boolean isImplicit() { return (modifiers & 0x8000) != 0; }
    public boolean isSynthetic() { return (modifiers & 0x1000) != 0; }
    public <T extends Annotation> T getAnnotation(Class<T> annotationClass) {
        for (Annotation a : getDeclaredAnnotations()) if (annotationClass.isInstance(a)) return annotationClass.cast(a);
        return null;
    }
    public Annotation[] getAnnotations() { return getDeclaredAnnotations(); }
    public Annotation[] getDeclaredAnnotations() {
        Annotation[][] pa = executable.getParameterAnnotations();
        return pa[index];
    }
    public AnnotatedType getAnnotatedType() { return executable.getAnnotatedParameterTypes()[index]; }
    public String toString() {
        StringBuilder sb = new StringBuilder();
        Type t = getParameterizedType();
        String tn = t.getTypeName();
        sb.append(Modifier.toString(getModifiers()));
        if (getModifiers() != 0) sb.append(' ');
        if (isVarArgs()) sb.append(tn.replaceFirst("\\[\\]$", "..."));
        else sb.append(tn);
        sb.append(' ');
        sb.append(name);
        return sb.toString();
    }
    public boolean equals(Object obj) {
        if (obj instanceof Parameter) {
            Parameter other = (Parameter) obj;
            return other.executable.equals(executable) && other.index == index;
        }
        return false;
    }
    public int hashCode() { return executable.hashCode() ^ index; }
}
