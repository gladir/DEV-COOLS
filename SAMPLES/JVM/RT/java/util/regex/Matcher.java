package java.util.regex;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Stream;
public final class Matcher implements MatchResult {
    static class Cont { Pattern.Loop loop; int count, start; Cont prev; }
    final Pattern pat;
    CharSequence text;
    int from, to;
    int[] gs, ge, gtmp;
    Cont cont;
    int sub, endTarget = -1;
    int matchStart = -1, matchEnd = -1;
    int appendPos;
    int searchFrom;
    boolean requireEnd;
    int acceptEnd;
    Matcher(Pattern p, CharSequence input) {
        pat = p; text = input; from = 0; to = input.length();
        gs = new int[p.groupCount + 1]; ge = new int[p.groupCount + 1]; gtmp = new int[p.groupCount + 1];
        Arrays.fill(gs, -1); Arrays.fill(ge, -1);
    }
    boolean accept(int i) {
        if (endTarget >= 0 && sub > 0) return i == endTarget;
        if (sub > 0) return true;
        if (requireEnd && i != to) return false;
        acceptEnd = i;
        return true;
    }
    public Pattern pattern() { return pat; }
    public Matcher reset() { Arrays.fill(gs, -1); Arrays.fill(ge, -1); matchStart = matchEnd = -1; appendPos = 0; searchFrom = 0; return this; }
    public Matcher reset(CharSequence input) { text = input; to = input.length(); return reset(); }
    private boolean tryAt(int i, boolean full) {
        Arrays.fill(gs, -1); Arrays.fill(ge, -1);
        cont = null; sub = 0; endTarget = -1;
        requireEnd = full;
        boolean r = pat.root.match(this, i);
        if (r) { matchStart = i; matchEnd = acceptEnd; gs[0] = i; ge[0] = acceptEnd; }
        return r;
    }
    public boolean matches() { return tryAt(from, true); }
    public boolean lookingAt() { return tryAt(from, false); }
    public boolean find() {
        int i = searchFrom;
        if (i > to) { matchStart = -1; return false; }
        for (; i <= to; i++) {
            if (tryAt(i, false)) {
                searchFrom = matchEnd == matchStart ? matchEnd + 1 : matchEnd;
                return true;
            }
        }
        matchStart = -1;
        searchFrom = to + 1;
        return false;
    }
    public boolean find(int start) {
        if (start < 0 || start > to) throw new IndexOutOfBoundsException("Illegal start index");
        reset();
        searchFrom = start;
        return find();
    }
    private void check() { if (matchStart < 0) throw new IllegalStateException("No match found"); }
    public int start() { check(); return matchStart; }
    public int end() { check(); return matchEnd; }
    public int start(int g) { check(); if (g < 0 || g > pat.groupCount) throw new IndexOutOfBoundsException("No group " + g); return gs[g]; }
    public int end(int g) { check(); if (g < 0 || g > pat.groupCount) throw new IndexOutOfBoundsException("No group " + g); return ge[g]; }
    public String group() { return group(0); }
    public String group(int g) {
        check();
        if (g < 0 || g > pat.groupCount) throw new IndexOutOfBoundsException("No group " + g);
        if (gs[g] < 0) return null;
        return text.subSequence(gs[g], ge[g]).toString();
    }
    public String group(String name) {
        Integer g = pat.names.get(name);
        if (g == null) throw new IllegalArgumentException("No group with name <" + name + ">");
        return group(g);
    }
    public int start(String name) { return start(pat.names.get(name)); }
    public int end(String name) { return end(pat.names.get(name)); }
    public int groupCount() { return pat.groupCount; }
    public boolean hitEnd() { return searchFrom >= to; }
    public MatchResult toMatchResult() {
        final Matcher m = new Matcher(pat, text.toString());
        m.matchStart = matchStart; m.matchEnd = matchEnd; m.gs = gs.clone(); m.ge = ge.clone();
        return m;
    }
    public Matcher region(int s, int e) { from = s; to = e; reset(); searchFrom = s; return this; }
    public static String quoteReplacement(String s) {
        if ((s.indexOf('\\') == -1) && (s.indexOf('$') == -1)) return s;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) { char c = s.charAt(i); if (c == '\\' || c == '$') sb.append('\\'); sb.append(c); }
        return sb.toString();
    }
    private void appendExpansion(StringBuilder sb, String repl) {
        int i = 0;
        while (i < repl.length()) {
            char c = repl.charAt(i++);
            if (c == '\\') {
                if (i >= repl.length()) throw new IllegalArgumentException("character to be escaped is missing");
                sb.append(repl.charAt(i++));
            } else if (c == '$') {
                if (i >= repl.length()) throw new IllegalArgumentException("Illegal group reference: group index is missing");
                char d = repl.charAt(i);
                if (d == '{') {
                    int q = repl.indexOf('}', i);
                    String nm = repl.substring(i + 1, q);
                    i = q + 1;
                    String g = group(nm);
                    if (g != null) sb.append(g);
                } else {
                    if (d < '0' || d > '9') throw new IllegalArgumentException("Illegal group reference");
                    int g = d - '0';
                    i++;
                    while (i < repl.length()) {
                        char e = repl.charAt(i);
                        if (e < '0' || e > '9') break;
                        int ng = g * 10 + (e - '0');
                        if (ng > pat.groupCount) break;
                        g = ng; i++;
                    }
                    if (g > pat.groupCount) throw new IndexOutOfBoundsException("No group " + g);
                    String s = group(g);
                    if (s != null) sb.append(s);
                }
            } else sb.append(c);
        }
    }
    public Matcher appendReplacement(StringBuilder sb, String repl) {
        check();
        sb.append(text, appendPos, matchStart);
        appendExpansion(sb, repl);
        appendPos = matchEnd;
        return this;
    }
    public Matcher appendReplacement(StringBuffer sb, String repl) {
        StringBuilder t = new StringBuilder();
        appendReplacement(t, repl);
        sb.append(t);
        return this;
    }
    public StringBuilder appendTail(StringBuilder sb) { sb.append(text, appendPos, text.length()); return sb; }
    public StringBuffer appendTail(StringBuffer sb) { sb.append(text.subSequence(appendPos, text.length()).toString()); return sb; }
    public String replaceAll(String replacement) {
        reset();
        boolean result = find();
        if (result) {
            StringBuilder sb = new StringBuilder();
            do { appendReplacement(sb, replacement); result = find(); } while (result);
            appendTail(sb);
            return sb.toString();
        }
        return text.toString();
    }
    public String replaceAll(Function<MatchResult, String> replacer) {
        reset();
        boolean result = find();
        if (result) {
            StringBuilder sb = new StringBuilder();
            do { appendReplacement(sb, replacer.apply(this)); result = find(); } while (result);
            appendTail(sb);
            return sb.toString();
        }
        return text.toString();
    }
    public String replaceFirst(String replacement) {
        reset();
        if (!find()) return text.toString();
        StringBuilder sb = new StringBuilder();
        appendReplacement(sb, replacement);
        appendTail(sb);
        return sb.toString();
    }
    public Stream<MatchResult> results() {
        ArrayList<MatchResult> l = new ArrayList<>();
        reset();
        while (find()) l.add(toMatchResult());
        return l.stream();
    }
    public String toString() { return "java.util.regex.Matcher[pattern=" + pat + " region=" + from + "," + to + " lastmatch=" + (matchStart >= 0 ? group() : "") + "]"; }
}
