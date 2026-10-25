package java.util;
public final class StringJoiner {
    private final String prefix, delimiter, suffix;
    private StringBuilder value;
    private String emptyValue;
    public StringJoiner(CharSequence delimiter) { this(delimiter, "", ""); }
    public StringJoiner(CharSequence delimiter, CharSequence prefix, CharSequence suffix) {
        this.prefix = prefix.toString(); this.delimiter = delimiter.toString(); this.suffix = suffix.toString();
    }
    public StringJoiner setEmptyValue(CharSequence emptyValue) { this.emptyValue = emptyValue.toString(); return this; }
    public String toString() {
        if (value == null) return emptyValue != null ? emptyValue : prefix + suffix;
        return prefix + value + suffix;
    }
    public StringJoiner add(CharSequence newElement) {
        if (value == null) value = new StringBuilder(); else value.append(delimiter);
        value.append(String.valueOf(newElement));
        return this;
    }
    public int length() { return toString().length(); }
}
