package java.text;
public class MessageFormat extends Format {
    private static final long serialVersionUID = 6479157306784022952L;
    private final String pattern;
    public MessageFormat(String pattern) { this.pattern = pattern; }
    public static String format(String pattern, Object... args) {
        StringBuilder sb = new StringBuilder();
        int i = 0, n = pattern.length();
        while (i < n) {
            char c = pattern.charAt(i);
            if (c == '\'') {
                if (i + 1 < n && pattern.charAt(i + 1) == '\'') { sb.append('\''); i += 2; continue; }
                int j = pattern.indexOf('\'', i + 1);
                if (j < 0) j = n;
                sb.append(pattern, i + 1, j); i = j + 1; continue;
            }
            if (c == '{') {
                int j = pattern.indexOf('}', i);
                String spec = pattern.substring(i + 1, j);
                int comma = spec.indexOf(',');
                int idx = Integer.parseInt((comma < 0 ? spec : spec.substring(0, comma)).trim());
                Object arg = idx < args.length ? args[idx] : null;
                if (idx >= args.length) sb.append('{').append(idx).append('}');
                else if (arg instanceof Number && comma < 0) sb.append(new DecimalFormat("#,##0.###").format(((Number) arg).doubleValue()));
                else sb.append(String.valueOf(arg));
                i = j + 1; continue;
            }
            sb.append(c); i++;
        }
        return sb.toString();
    }
    String formatObject(Object o) { return format(pattern, (Object[]) o); }
}
