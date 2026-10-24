package java.time.format;
import java.time.*;
import java.util.*;
public final class DateTimeFormatter {
    public static final DateTimeFormatter ISO_LOCAL_DATE = new DateTimeFormatter("yyyy-MM-dd", 1);
    public static final DateTimeFormatter ISO_DATE = ISO_LOCAL_DATE;
    public static final DateTimeFormatter ISO_LOCAL_TIME = new DateTimeFormatter("HH:mm:ss", 2);
    public static final DateTimeFormatter ISO_LOCAL_DATE_TIME = new DateTimeFormatter("yyyy-MM-dd'T'HH:mm:ss", 3);
    public static final DateTimeFormatter BASIC_ISO_DATE = new DateTimeFormatter("yyyyMMdd", 1);
    private final String pattern;
    private final int kind;
    private final Locale locale;
    private DateTimeFormatter(String p, int kind) { this(p, kind, Locale.US); }
    private DateTimeFormatter(String p, int kind, Locale l) { pattern = p; this.kind = kind; locale = l; }
    public static DateTimeFormatter ofPattern(String p) { check(p); return new DateTimeFormatter(p, 0); }
    public static DateTimeFormatter ofPattern(String p, Locale l) { check(p); return new DateTimeFormatter(p, 0, l); }
    public DateTimeFormatter withLocale(Locale l) { return new DateTimeFormatter(pattern, kind, l); }
    private static void check(String p) {
        for (int i = 0; i < p.length(); i++) {
            char c = p.charAt(i);
            if (c == '\'') { int j = p.indexOf('\'', i + 1); if (j < 0) throw new IllegalArgumentException("Pattern ends with an incomplete string literal: " + p); i = j; }
            else if (Character.isLetter(c) && "yMdHhmsSaEeuLnD".indexOf(c) < 0) throw new IllegalArgumentException("Unknown pattern letter: " + c);
        }
    }
    public Locale getLocale() { return locale; }
    public String toString() { return pattern; }
    private static String pad(long v, int n) { String s = Long.toString(Math.abs(v)); StringBuilder sb = new StringBuilder(); if (v < 0) sb.append('-'); for (int i = s.length(); i < n; i++) sb.append('0'); return sb.append(s).toString(); }
    public String format(Object t) {
        LocalDate d = null; LocalTime tm = null;
        if (t instanceof LocalDate x) d = x; else if (t instanceof LocalTime x) tm = x; else if (t instanceof LocalDateTime x) { d = x.toLocalDate(); tm = x.toLocalTime(); } else throw new DateTimeException("Unsupported temporal");
        StringBuilder sb = new StringBuilder();
        String p = pattern;
        int i = 0;
        while (i < p.length()) {
            char c = p.charAt(i);
            if (c == '\'') {
                int j = p.indexOf('\'', i + 1);
                if (j == i + 1) { sb.append('\''); i += 2; continue; }
                sb.append(p, i + 1, j); i = j + 1; continue;
            }
            if (!Character.isLetter(c)) { sb.append(c); i++; continue; }
            int j = i;
            while (j < p.length() && p.charAt(j) == c) j++;
            int n = j - i;
            i = j;
            switch (c) {
                case 'y': case 'u': { if (d == null) throw new DateTimeException("Unsupported field: YearOfEra"); int y = d.getYear(); sb.append(n == 2 ? pad(y % 100, 2) : pad(y, n)); break; }
                case 'M': case 'L': {
                    if (d == null) throw new DateTimeException("Unsupported field: MonthOfYear");
                    if (n <= 2) sb.append(pad(d.getMonthValue(), n));
                    else sb.append(d.getMonth().getDisplayName(n == 3 ? TextStyle.SHORT : TextStyle.FULL, locale));
                    break;
                }
                case 'd': if (d == null) throw new DateTimeException("Unsupported field: DayOfMonth"); sb.append(pad(d.getDayOfMonth(), n)); break;
                case 'D': if (d == null) throw new DateTimeException("Unsupported field: DayOfYear"); sb.append(pad(d.getDayOfYear(), n)); break;
                case 'E': case 'e': if (d == null) throw new DateTimeException("Unsupported field: DayOfWeek"); sb.append(d.getDayOfWeek().getDisplayName(n >= 4 ? TextStyle.FULL : TextStyle.SHORT, locale)); break;
                case 'H': if (tm == null) throw new DateTimeException("Unsupported field: HourOfDay"); sb.append(pad(tm.getHour(), n)); break;
                case 'h': { if (tm == null) throw new DateTimeException("Unsupported field: ClockHourOfAmPm"); int h = tm.getHour() % 12; if (h == 0) h = 12; sb.append(pad(h, n)); break; }
                case 'm': if (tm == null) throw new DateTimeException("Unsupported field: MinuteOfHour"); sb.append(pad(tm.getMinute(), n)); break;
                case 's': if (tm == null) throw new DateTimeException("Unsupported field: SecondOfMinute"); sb.append(pad(tm.getSecond(), n)); break;
                case 'S': { if (tm == null) throw new DateTimeException("Unsupported field: NanoOfSecond"); String f = pad(tm.getNano(), 9); sb.append(f, 0, Math.min(n, 9)); break; }
                case 'n': sb.append(pad(tm.getNano(), n)); break;
                case 'a': if (tm == null) throw new DateTimeException("Unsupported field: AmPmOfDay"); sb.append(tm.getHour() < 12 ? "AM" : "PM"); break;
                default: throw new IllegalArgumentException("Unknown pattern letter: " + c);
            }
        }
        return sb.toString();
    }
    // lecture : champs numeriques et noms de mois courts
    private int[] parse(String s) {
        int[] f = { -1, -1, -1, -1, -1, -1, 0, -1 }; // y M d H m s nano ampm
        String p = pattern;
        int i = 0, k = 0;
        try {
            while (i < p.length()) {
                char c = p.charAt(i);
                if (c == '\'') { int j = p.indexOf('\'', i + 1); String lit = p.substring(i + 1, j); if (!s.startsWith(lit, k)) throw new RuntimeException(); k += lit.length(); i = j + 1; continue; }
                if (!Character.isLetter(c)) { if (k >= s.length() || s.charAt(k) != c) throw new RuntimeException(); k++; i++; continue; }
                int j = i;
                while (j < p.length() && p.charAt(j) == c) j++;
                int n = j - i; i = j;
                if ((c == 'M' || c == 'L') && n >= 3) {
                    int found = -1;
                    for (Month m : Month.values()) { String nm = m.getDisplayName(n == 3 ? TextStyle.SHORT : TextStyle.FULL, locale); if (s.regionMatches(true, k, nm, 0, nm.length())) { found = m.getValue(); k += nm.length(); break; } }
                    if (found < 0) throw new RuntimeException();
                    f[1] = found; continue;
                }
                if (c == 'E') { int e = k; while (e < s.length() && Character.isLetter(s.charAt(e))) e++; k = e; continue; }
                if (c == 'a') { f[7] = s.regionMatches(true, k, "PM", 0, 2) ? 1 : 0; k += 2; continue; }
                int e = k;
                int maxw = (n == 1 || (c == 'y' && n != 2)) ? 9 : n;
                if (c == 'y' && n == 4) maxw = 4;
                while (e < s.length() && Character.isDigit(s.charAt(e)) && e - k < maxw) e++;
                if (e == k) throw new RuntimeException();
                int v = Integer.parseInt(s.substring(k, e));
                k = e;
                switch (c) { case 'y': case 'u': f[0] = (n == 2) ? 2000 + v : v; break; case 'M': case 'L': f[1] = v; break; case 'd': f[2] = v; break; case 'H': f[3] = v; break; case 'h': f[3] = v % 12; break; case 'm': f[4] = v; break; case 's': f[5] = v; break; case 'S': f[6] = v * (int) Math.pow(10, 9 - n); break; }
            }
            if (k != s.length()) throw new RuntimeException();
        } catch (RuntimeException e) { throw new DateTimeParseException("Text '" + s + "' could not be parsed at index " + Math.min(k, s.length()), s, k); }
        if (f[7] == 1 && f[3] >= 0) f[3] += 12;
        return f;
    }
    public LocalDate parseDate(String s) {
        int[] f = parse(s);
        try { return LocalDate.of(f[0], f[1], f[2]); } catch (DateTimeException e) { throw new DateTimeParseException("Text '" + s + "' could not be parsed: " + e.getMessage(), s, 0); }
    }
    public LocalTime parseTime(String s) { int[] f = parse(s); return LocalTime.of(f[3], f[4], Math.max(f[5], 0), f[6]); }
    public LocalDateTime parseDateTime(String s) {
        int[] f = parse(s);
        try { return LocalDateTime.of(LocalDate.of(f[0], f[1], f[2]), LocalTime.of(Math.max(f[3], 0), Math.max(f[4], 0), Math.max(f[5], 0), f[6])); }
        catch (DateTimeException e) { throw new DateTimeParseException("Text '" + s + "' could not be parsed: " + e.getMessage(), s, 0); }
    }
}
