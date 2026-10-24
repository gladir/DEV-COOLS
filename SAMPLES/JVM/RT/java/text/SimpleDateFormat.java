package java.text;
import java.util.*;
import java.time.*;
import java.time.format.*;
public class SimpleDateFormat extends DateFormat {
    private final String pattern;
    private final DateTimeFormatter f;
    public SimpleDateFormat() { this("M/d/yy, h:mm a"); }
    public SimpleDateFormat(String pattern) { this.pattern = pattern; this.f = DateTimeFormatter.ofPattern(pattern.replace("EEE", "EEE").replace("Z", "'+0000'").replace("z", "'UTC'")); }
    public SimpleDateFormat(String pattern, Locale l) { this.pattern = pattern; this.f = DateTimeFormatter.ofPattern(pattern.replace("Z", "'+0000'").replace("z", "'UTC'"), l); }
    public String toPattern() { return pattern; }
    public String format(Date d) { return f.format(LocalDateTime.ofEpochSecond(Math.floorDiv(d.getTime(), 1000L), (int) Math.floorMod(d.getTime(), 1000L) * 1000000)); }
    public Date parse(String s) throws ParseException {
        try {
            LocalDateTime t = f.parseDateTime(s);
            return new Date(t.toEpochDay() * 86400000L + t.toLocalTime().toNanoOfDay() / 1000000L);
        } catch (DateTimeException e) {
            try {
                LocalDate d = f.parseDate(s);
                return new Date(d.toEpochDay() * 86400000L);
            } catch (DateTimeException e2) { throw new ParseException("Unparseable date: \"" + s + "\"", 0); }
        }
    }
}
