package java.util.regex;
import java.util.*;
import java.util.function.Predicate;
import java.util.stream.Stream;
public final class Pattern implements java.io.Serializable {
    private static final long serialVersionUID = 5073258162644648461L;
    public static final int UNIX_LINES = 1, CASE_INSENSITIVE = 2, COMMENTS = 4, MULTILINE = 8, LITERAL = 16, DOTALL = 32, UNICODE_CASE = 64;
    private String pattern;
    private int flags;
    transient Node root;
    transient int groupCount;
    transient Map<String, Integer> names = new HashMap<>();
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        names = new HashMap<>();
        Parser ps = new Parser(pattern, flags, this);
        root = ps.parseAll();
        groupCount = ps.groups;
    }
    private Pattern(String p, int f) {
        pattern = p; flags = f;
        Parser ps = new Parser(p, f, this);
        root = ps.parseAll();
        groupCount = ps.groups;
    }
    public static Pattern compile(String regex) { return new Pattern(regex, 0); }
    public static Pattern compile(String regex, int flags) { return new Pattern(regex, flags); }
    public String pattern() { return pattern; }
    public String toString() { return pattern; }
    public int flags() { return flags; }
    public Matcher matcher(CharSequence input) { return new Matcher(this, input); }
    public static boolean matches(String regex, CharSequence input) { return compile(regex).matcher(input).matches(); }
    public static String quote(String s) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) { char c = s.charAt(i); if ("\\.[]{}()*+-?^$|".indexOf(c) >= 0) sb.append('\\'); sb.append(c); }
        return sb.toString();
    }
    public String[] split(CharSequence input) { return split(input, 0); }
    public String[] split(CharSequence input, int limit) {
        int index = 0;
        boolean matchLimited = limit > 0;
        ArrayList<String> matchList = new ArrayList<>();
        Matcher m = matcher(input);
        while (m.find()) {
            if (!matchLimited || matchList.size() < limit - 1) {
                if (index == 0 && index == m.start() && m.start() == m.end()) continue;
                matchList.add(input.subSequence(index, m.start()).toString());
                index = m.end();
            } else if (matchList.size() == limit - 1) {
                matchList.add(input.subSequence(index, input.length()).toString());
                index = m.end();
            }
        }
        if (index == 0) return new String[] { input.toString() };
        if (!matchLimited || matchList.size() < limit) matchList.add(input.subSequence(index, input.length()).toString());
        int resultSize = matchList.size();
        if (limit == 0) while (resultSize > 0 && matchList.get(resultSize - 1).isEmpty()) resultSize--;
        return matchList.subList(0, resultSize).toArray(new String[resultSize]);
    }
    public Stream<String> splitAsStream(CharSequence input) { return Arrays.stream(split(input)); }
    public Predicate<String> asPredicate() { return s -> matcher(s).find(); }
    public Predicate<String> asMatchPredicate() { return s -> matcher(s).matches(); }

    // ---- noeuds ----
    abstract static class Node {
        Node next;
        abstract boolean match(Matcher m, int i);
    }
    static boolean matchNext(Node n, Matcher m, int i) { return n == null ? m.accept(i) : n.match(m, i); }
    static class End extends Node { boolean match(Matcher m, int i) { return m.accept(i); } }
    static class Char extends Node {
        final int c; final boolean ci;
        Char(int c, boolean ci) { this.c = c; this.ci = ci; }
        boolean match(Matcher m, int i) {
            if (i >= m.to) return false;
            char d = m.text.charAt(i);
            if (d == c || (ci && Character.toLowerCase(d) == Character.toLowerCase((char) c))) return matchNext(next, m, i + 1);
            return false;
        }
    }
    static class Any extends Node {
        final boolean dotall;
        Any(boolean d) { dotall = d; }
        boolean match(Matcher m, int i) {
            if (i >= m.to) return false;
            char d = m.text.charAt(i);
            if (!dotall && (d == '\n' || d == '\r')) return false;
            return matchNext(next, m, i + 1);
        }
    }
    static class CharSet extends Node {
        boolean neg;
        ArrayList<int[]> ranges = new ArrayList<>();
        ArrayList<CharSet> subs = new ArrayList<>();
        ArrayList<CharSet> inter = new ArrayList<>();
        boolean ci;
        char cls; // classe predefinie : d w s D W S, 0 sinon
        boolean has(char c) {
            boolean r = false;
            for (int[] rg : ranges) if (c >= rg[0] && c <= rg[1]) { r = true; break; }
            if (!r && ci) {
                char l = Character.toLowerCase(c), u = Character.toUpperCase(c);
                for (int[] rg : ranges) if ((l >= rg[0] && l <= rg[1]) || (u >= rg[0] && u <= rg[1])) { r = true; break; }
            }
            if (!r) for (CharSet s : subs) if (s.has(c)) { r = true; break; }
            if (r) for (CharSet s : inter) if (!s.has(c)) { r = false; break; }
            return neg ? !r : r;
        }
        boolean match(Matcher m, int i) {
            if (i >= m.to) return false;
            return has(m.text.charAt(i)) && matchNext(next, m, i + 1);
        }
    }
    static boolean isWord(char c) { return Character.isLetterOrDigit(c) || c == '_'; }
    static class Predef extends Node {
        final char k;
        Predef(char k) { this.k = k; }
        static boolean test(char k, char c) {
            switch (k) {
                case 'd': return c >= '0' && c <= '9';
                case 'D': return !(c >= '0' && c <= '9');
                case 'w': return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
                case 'W': return !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_');
                case 's': return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == 0x0B;
                case 'S': return !(c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == 0x0B);
                case 'p': return Character.isLetter(c);
                case 'P': return !Character.isLetter(c);
            }
            return false;
        }
        boolean match(Matcher m, int i) { return i < m.to && test(k, m.text.charAt(i)) && matchNext(next, m, i + 1); }
    }
    static class Begin extends Node {
        final boolean multi;
        Begin(boolean m) { multi = m; }
        boolean match(Matcher m, int i) { return (i == m.from || (multi && i > 0 && m.text.charAt(i - 1) == '\n')) && matchNext(next, m, i); }
    }
    static class Dollar extends Node {
        final boolean multi;
        Dollar(boolean m) { multi = m; }
        boolean match(Matcher m, int i) {
            boolean ok = i == m.to || (multi && m.text.charAt(i) == '\n') || (i == m.to - 1 && m.text.charAt(i) == '\n');
            return ok && matchNext(next, m, i);
        }
    }
    static class WordB extends Node {
        final boolean neg;
        WordB(boolean n) { neg = n; }
        boolean match(Matcher m, int i) {
            boolean a = i > 0 && isWord(m.text.charAt(i - 1)), b = i < m.to && isWord(m.text.charAt(i));
            return ((a != b) != neg) && matchNext(next, m, i);
        }
    }
    static class Seq extends Node {
        Node first;
        boolean match(Matcher m, int i) { return first == null ? matchNext(next, m, i) : first.match(m, i); }
    }
    static class Alt extends Node {
        final ArrayList<Node> alts = new ArrayList<>();
        boolean match(Matcher m, int i) { for (Node a : alts) if (a.match(m, i)) return true; return false; }
    }
    static class Join extends Node {
        final Alt owner;
        Join(Alt a) { owner = a; }
        boolean match(Matcher m, int i) { return matchNext(owner.next, m, i); }
    }
    // un groupe : le contenu se termine par un noeud GroupEnd qui continue sur `next` du groupe
    static class Group extends Node {
        Node body; final int idx;
        Group(int idx) { this.idx = idx; }
        boolean match(Matcher m, int i) {
            int os = idx > 0 ? m.gs[idx] : 0, oe = idx > 0 ? m.ge[idx] : 0;
            boolean r = body.match(m, i);
            if (!r && idx > 0) { m.gs[idx] = os; m.ge[idx] = oe; }
            return r;
        }
    }
    static class GStart extends Node {
        final int idx;
        GStart(int i) { idx = i; }
        boolean match(Matcher m, int i) {
            int o = m.gtmp[idx]; m.gtmp[idx] = i;
            if (matchNext(next, m, i)) return true;
            m.gtmp[idx] = o; return false;
        }
    }
    static class GEnd extends Node {
        final int idx;
        GEnd(int i) { idx = i; }
        boolean match(Matcher m, int i) {
            int os = m.gs[idx], oe = m.ge[idx];
            m.gs[idx] = m.gtmp[idx]; m.ge[idx] = i;
            if (matchNext(next, m, i)) return true;
            m.gs[idx] = os; m.ge[idx] = oe; return false;
        }
    }
    static class BackRef extends Node {
        final int idx; final boolean ci;
        BackRef(int i, boolean ci) { idx = i; this.ci = ci; }
        boolean match(Matcher m, int i) {
            int s = m.gs[idx], e = m.ge[idx];
            if (s < 0) return false;
            int len = e - s;
            if (i + len > m.to) return false;
            for (int k = 0; k < len; k++) {
                char a = m.text.charAt(s + k), b = m.text.charAt(i + k);
                if (a != b && !(ci && Character.toLowerCase(a) == Character.toLowerCase(b))) return false;
            }
            return matchNext(next, m, i + len);
        }
    }
    static class Look extends Node {
        Node body; final boolean ahead, neg;
        Look(boolean ahead, boolean neg) { this.ahead = ahead; this.neg = neg; }
        boolean match(Matcher m, int i) {
            boolean r;
            if (ahead) {
                Matcher.Cont saved = m.cont;
                m.cont = null;
                m.sub++;
                r = body.match(m, i);
                m.sub--;
                m.cont = saved;
            } else {
                r = false;
                for (int st = i; st >= 0 && !r; st--) {
                    final int target = i;
                    Matcher.Cont saved = m.cont;
                    m.cont = null;
                    m.endTarget = target;
                    m.sub++;
                    r = body.match(m, st);
                    m.sub--;
                    m.endTarget = -1;
                    m.cont = saved;
                }
            }
            if (r == neg) return false;
            return matchNext(next, m, i);
        }
    }
    static class Loop extends Node {
        Node body; final int min, max; final int mode; // 0 gourmand, 1 paresseux, 2 possessif
        Loop(int min, int max, int mode) { this.min = min; this.max = max; this.mode = mode; }
        boolean match(Matcher m, int i) { return rec(m, i, 0, -1); }
        boolean rec(Matcher m, int i, int count, int lastPos) {
            if (mode == 1) {
                if (count >= min && matchNext(next, m, i)) return true;
                if (count < max && i != lastPos) return body_(m, i, count);
                return false;
            }
            if (count < max && i != lastPos) { if (body_(m, i, count)) return true; }
            return count >= min && matchNext(next, m, i);
        }
        boolean body_(Matcher m, int i, int count) {
            Matcher.Cont c = new Matcher.Cont();
            c.loop = this; c.count = count + 1; c.start = i; c.prev = m.cont;
            m.cont = c;
            boolean r = body.match(m, i);
            m.cont = c.prev;
            return r;
        }
    }
    // fin du corps d'une boucle
    static class LoopEnd extends Node {
        boolean match(Matcher m, int i) {
            Matcher.Cont c = m.cont;
            if (c == null) return matchNext(next, m, i);
            m.cont = c.prev;
            boolean r = c.loop.rec(m, i, c.count, c.start);
            m.cont = c;
            return r;
        }
    }
    static class Parser {
        final String s; int p; int flags; int groups; final Pattern pat;
        Parser(String s, int flags, Pattern pat) { this.s = s; this.flags = flags; this.pat = pat; }
        boolean ci() { return (flags & CASE_INSENSITIVE) != 0; }
        Node parseAll() {
            if ((flags & LITERAL) != 0) {
                Seq q = new Seq(); Node last = null;
                for (int i = 0; i < s.length(); i++) { Node c = new Char(s.charAt(i), ci()); if (last == null) q.first = c; else last.next = c; last = c; }
                return q;
            }
            Node n = parseAlt();
            if (p < s.length()) throw new PatternSyntaxException("Unmatched closing ')'", s, p - 1);
            return n;
        }
        // chaine un noeud a la suite : retourne le dernier
        Node parseAlt() {
            ArrayList<Node> branches = new ArrayList<>();
            branches.add(parseSeq());
            while (p < s.length() && s.charAt(p) == '|') { p++; branches.add(parseSeq()); }
            if (branches.size() == 1) return branches.get(0);
            Alt a = new Alt();
            Seq wrap = new Seq();
            wrap.first = a;
            for (Node b : branches) { a.alts.add(b); Join j = new Join(a); lastOf(b).next = j; }
            return wrap;
        }
        Node parseSeq() {
            Seq q = new Seq();
            Node last = null;
            while (p < s.length() && s.charAt(p) != '|' && s.charAt(p) != ')') {
                Node[] ends = parseQuant();
                if (ends == null) continue;
                if (last == null) q.first = ends[0]; else last.next = ends[0];
                last = ends[1];
            }
            return q;
        }
        // retourne {debut, fin}
        Node[] parseQuant() {
            Node[] atom = parseAtom();
            if (atom == null) return null;
            if (p >= s.length()) return atom;
            char c = s.charAt(p);
            int min = -1, max = -1;
            if (c == '*') { min = 0; max = Integer.MAX_VALUE; p++; }
            else if (c == '+') { min = 1; max = Integer.MAX_VALUE; p++; }
            else if (c == '?') { min = 0; max = 1; p++; }
            else if (c == '{' && p + 1 < s.length() && Character.isDigit(s.charAt(p + 1))) {
                int q = p + 1;
                int a = 0;
                while (q < s.length() && Character.isDigit(s.charAt(q))) a = a * 10 + (s.charAt(q++) - '0');
                int b = a;
                if (q < s.length() && s.charAt(q) == ',') {
                    q++;
                    if (q < s.length() && s.charAt(q) == '}') b = Integer.MAX_VALUE;
                    else { b = 0; while (q < s.length() && Character.isDigit(s.charAt(q))) b = b * 10 + (s.charAt(q++) - '0'); }
                }
                if (q >= s.length() || s.charAt(q) != '}') throw new PatternSyntaxException("Unclosed counted closure", s, q);
                p = q + 1; min = a; max = b;
            } else return atom;
            int mode = 0;
            if (p < s.length() && s.charAt(p) == '?') { mode = 1; p++; }
            else if (p < s.length() && s.charAt(p) == '+') { mode = 2; p++; }
            Loop l = new Loop(min, max, mode);
            LoopEnd le = new LoopEnd();
            atom[1].next = le;
            l.body = atom[0];
            if (mode == 2) {
                // possessif : on ne revient pas en arriere : on isole le corps
                Look lk = new Look(true, false);
                return new Node[] { l, l };
            }
            return new Node[] { l, l };
        }
        int escChar() {
            // apres le backslash : p sur le caractere
            char c = s.charAt(p++);
            switch (c) {
                case 't': return '\t'; case 'n': return '\n'; case 'r': return '\r'; case 'f': return '\f'; case 'a': return 7; case 'e': return 27;
                case '0': { int v = 0; while (p < s.length() && s.charAt(p) >= '0' && s.charAt(p) <= '7') v = v * 8 + (s.charAt(p++) - '0'); return v; }
                case 'x': { int v = Integer.parseInt(s.substring(p, p + 2), 16); p += 2; return v; }
                case 'u': { int v = Integer.parseInt(s.substring(p, p + 4), 16); p += 4; return v; }
                default: return c;
            }
        }
        Node[] single(Node n) { return new Node[] { n, n }; }
        Node[] parseAtom() {
            char c = s.charAt(p);
            if ((flags & COMMENTS) != 0) {
                if (Character.isWhitespace(c)) { p++; return null; }
                if (c == '#') { while (p < s.length() && s.charAt(p) != '\n') p++; return null; }
            }
            switch (c) {
                case '(': return parseGroup();
                case '[': { p++; CharSet cs = parseClass(); return single(cs); }
                case '.': p++; return single(new Any((flags & DOTALL) != 0));
                case '^': p++; return single(new Begin((flags & MULTILINE) != 0));
                case '$': p++; return single(new Dollar((flags & MULTILINE) != 0));
                case '\\': {
                    p++;
                    if (p >= s.length()) throw new PatternSyntaxException("Unexpected internal error", s, p);
                    char e = s.charAt(p);
                    if ("dDwWsS".indexOf(e) >= 0) { p++; return single(new Predef(e)); }
                    if (e == 'b') { p++; return single(new WordB(false)); }
                    if (e == 'B') { p++; return single(new WordB(true)); }
                    if (e == 'A') { p++; return single(new Begin(false)); }
                    if (e == 'z' || e == 'Z') { p++; return single(new Dollar(false)); }
                    if (e == 'p' || e == 'P') {
                        p++;
                        String name = "";
                        if (p < s.length() && s.charAt(p) == '{') { int q = s.indexOf('}', p); name = s.substring(p + 1, q); p = q + 1; }
                        else name = String.valueOf(s.charAt(p++));
                        CharSet cs = new CharSet();
                        cs.cls = 'p';
                        Node pn = new PropNode(name, e == 'P');
                        return single(pn);
                    }
                    if (e >= '1' && e <= '9') { p++; int idx = e - '0'; return single(new BackRef(idx, ci())); }
                    if (e == 'k' && p + 1 < s.length() && s.charAt(p + 1) == '<') {
                        int q = s.indexOf('>', p);
                        String nm = s.substring(p + 2, q); p = q + 1;
                        Integer gi = pat.names.get(nm);
                        if (gi == null) throw new PatternSyntaxException("named capturing group <" + nm + "> does not exist", s, p);
                        return single(new BackRef(gi, ci()));
                    }
                    if (e == 'Q') {
                        int q = s.indexOf("\\E", p + 1);
                        String lit = q < 0 ? s.substring(p + 1) : s.substring(p + 1, q);
                        p = q < 0 ? s.length() : q + 2;
                        Seq sq = new Seq(); Node last = null;
                        for (int i = 0; i < lit.length(); i++) { Node ch = new Char(lit.charAt(i), ci()); if (last == null) sq.first = ch; else last.next = ch; last = ch; }
                        if (last == null) return null;
                        return new Node[] { sq, last };
                    }
                    int ch = escChar();
                    return single(new Char(ch, ci()));
                }
                case '*': case '+': case '?': throw new PatternSyntaxException("Dangling meta character '" + c + "'", s, p);
                default: p++; return single(new Char(c, ci()));
            }
        }
        Node[] parseGroup() {
            p++; // (
            int idx = -1;
            boolean capture = true;
            Look look = null;
            int saveFlags = flags;
            String name = null;
            if (p < s.length() && s.charAt(p) == '?') {
                p++;
                char k = s.charAt(p);
                if (k == ':') { p++; capture = false; }
                else if (k == '=') { p++; capture = false; look = new Look(true, false); }
                else if (k == '!') { p++; capture = false; look = new Look(true, true); }
                else if (k == '>') { p++; capture = false; }
                else if (k == '<' && (s.charAt(p + 1) == '=' || s.charAt(p + 1) == '!')) { boolean neg = s.charAt(p + 1) == '!'; p += 2; capture = false; look = new Look(false, neg); }
                else if (k == '<') { int q = s.indexOf('>', p); name = s.substring(p + 1, q); p = q + 1; }
                else {
                    // drapeaux
                    boolean on = true;
                    int f = flags;
                    while (p < s.length() && s.charAt(p) != ')' && s.charAt(p) != ':') {
                        char fc = s.charAt(p++);
                        int bit = fc == 'i' ? CASE_INSENSITIVE : fc == 'm' ? MULTILINE : fc == 's' ? DOTALL : fc == 'x' ? COMMENTS : fc == 'u' ? UNICODE_CASE : fc == 'd' ? UNIX_LINES : 0;
                        if (fc == '-') on = false; else if (on) f |= bit; else f &= ~bit;
                    }
                    if (s.charAt(p) == ')') { p++; flags = f; return null; }
                    p++; flags = f; capture = false;
                }
            }
            if (capture) { idx = ++groups; if (name != null) pat.names.put(name, idx); }
            Node body = parseAlt();
            if (p >= s.length() || s.charAt(p) != ')') throw new PatternSyntaxException("Unclosed group", s, p);
            p++;
            flags = saveFlags;
            if (look != null) {
                // le corps se termine sur place (acceptation)
                Seq b = new Seq(); b.first = body; Node last = lastOf(body); last.next = new End();
                look.body = body;
                return single(look);
            }
            if (idx >= 0) {
                GStart gs = new GStart(idx);
                GEnd ge = new GEnd(idx);
                gs.next = body;
                Node last = lastOf(body);
                last.next = ge;
                return new Node[] { gs, ge };
            }
            Seq wrapper = new Seq();
            wrapper.first = body;
            Node last = lastOf(body);
            Seq tail = new Seq();
            last.next = tail;
            return new Node[] { wrapper, tail };
        }
        Node lastOf(Node n) {
            // dernier noeud de la chaine : on descend par next
            if (n instanceof Seq sq) {
                if (sq.first == null) { Seq t = new Seq(); sq.first = t; return t; }
                Node k = sq.first;
                Node prevNode = null;
                while (k != null) { prevNode = k; k = k.next; }
                if (prevNode instanceof Alt || prevNode instanceof Loop || prevNode instanceof Seq) {
                    Seq t = new Seq();
                    // les branches se terminent sur t
                    prevNode.next = t;
                    return t;
                }
                return prevNode;
            }
            return n;
        }
        CharSet parseClass() {
            CharSet cs = new CharSet();
            cs.ci = ci();
            if (p < s.length() && s.charAt(p) == '^') { cs.neg = true; p++; }
            boolean first = true;
            while (p < s.length()) {
                char c = s.charAt(p);
                if (c == ']' && !first) { p++; return cs; }
                first = false;
                if (c == '[') { p++; cs.subs.add(parseClass()); continue; }
                if (c == '&' && p + 1 < s.length() && s.charAt(p + 1) == '&') {
                    p += 2;
                    CharSet rest = new CharSet(); rest.ci = ci();
                    if (p < s.length() && s.charAt(p) == '[') { p++; rest = parseClass(); }
                    else {
                        // reste jusqu'a ]
                        CharSet r2 = new CharSet(); r2.ci = ci();
                        while (p < s.length() && s.charAt(p) != ']') { int lo = classAtom(r2); if (lo >= 0) r2.ranges.add(new int[] { lo, lo }); }
                        rest = r2;
                    }
                    cs.inter.add(rest);
                    continue;
                }
                int lo = classAtom(cs);
                if (lo < 0) continue;
                if (p + 1 < s.length() && s.charAt(p) == '-' && s.charAt(p + 1) != ']') {
                    p++;
                    CharSet dummy = new CharSet();
                    int hi = classAtom(dummy);
                    if (hi < 0) throw new PatternSyntaxException("Illegal character range", s, p);
                    if (hi < lo) throw new PatternSyntaxException("Illegal character range", s, p - 1);
                    cs.ranges.add(new int[] { lo, hi });
                } else cs.ranges.add(new int[] { lo, lo });
            }
            throw new PatternSyntaxException("Unclosed character class", s, s.length() - 1);
        }
        int classAtom(CharSet cs) {
            char c = s.charAt(p++);
            if (c == '\\') {
                char e = s.charAt(p);
                if (e == 'd') { p++; cs.ranges.add(new int[] { '0', '9' }); return -1; }
                if (e == 'w') { p++; cs.ranges.add(new int[] { 'a', 'z' }); cs.ranges.add(new int[] { 'A', 'Z' }); cs.ranges.add(new int[] { '0', '9' }); cs.ranges.add(new int[] { '_', '_' }); return -1; }
                if (e == 's') { p++; cs.ranges.add(new int[] { ' ', ' ' }); cs.ranges.add(new int[] { '\t', '\r' }); return -1; }
                if (e == 'D' || e == 'W' || e == 'S') {
                    p++;
                    CharSet sub = new CharSet();
                    char lc = Character.toLowerCase(e);
                    if (lc == 'd') sub.ranges.add(new int[] { '0', '9' });
                    else if (lc == 'w') { sub.ranges.add(new int[] { 'a', 'z' }); sub.ranges.add(new int[] { 'A', 'Z' }); sub.ranges.add(new int[] { '0', '9' }); sub.ranges.add(new int[] { '_', '_' }); }
                    else { sub.ranges.add(new int[] { ' ', ' ' }); sub.ranges.add(new int[] { '\t', '\r' }); }
                    sub.neg = true;
                    cs.subs.add(sub);
                    return -1;
                }
                if (e == 'p' || e == 'P') { p++; String nm; if (s.charAt(p) == '{') { int q = s.indexOf('}', p); nm = s.substring(p + 1, q); p = q + 1; } else nm = String.valueOf(s.charAt(p++)); addProp(cs, nm, e == 'P'); return -1; }
                return escChar();
            }
            return c;
        }
        void addProp(CharSet cs, String nm, boolean neg) {
            CharSet sub = new CharSet();
            if (nm.equals("Alpha") || nm.equals("L") || nm.equals("IsAlphabetic") || nm.equals("javaLetter")) { sub.ranges.add(new int[] { 'a', 'z' }); sub.ranges.add(new int[] { 'A', 'Z' }); sub.ranges.add(new int[] { 0xC0, 0x24F }); }
            else if (nm.equals("Digit") || nm.equals("N") || nm.equals("Nd")) sub.ranges.add(new int[] { '0', '9' });
            else if (nm.equals("Alnum")) { sub.ranges.add(new int[] { 'a', 'z' }); sub.ranges.add(new int[] { 'A', 'Z' }); sub.ranges.add(new int[] { '0', '9' }); }
            else if (nm.equals("Upper") || nm.equals("Lu")) sub.ranges.add(new int[] { 'A', 'Z' });
            else if (nm.equals("Lower") || nm.equals("Ll")) sub.ranges.add(new int[] { 'a', 'z' });
            else if (nm.equals("Punct") || nm.equals("P")) { sub.ranges.add(new int[] { '!', '/' }); sub.ranges.add(new int[] { ':', '@' }); sub.ranges.add(new int[] { '[', '`' }); sub.ranges.add(new int[] { '{', '~' }); }
            else if (nm.equals("Space")) { sub.ranges.add(new int[] { ' ', ' ' }); sub.ranges.add(new int[] { '\t', '\r' }); }
            else throw new PatternSyntaxException("Unknown character property name {" + nm + "}", s, p);
            sub.neg = neg;
            cs.subs.add(sub);
        }
    }
    static class PropNode extends Node {
        final String name; final boolean neg;
        PropNode(String n, boolean neg) { name = n; this.neg = neg; }
        boolean test(char c) {
            switch (name) {
                case "L": case "Alpha": case "IsAlphabetic": case "javaLetter": case "IsLetter": return Character.isLetter(c);
                case "Lu": case "Upper": case "IsUppercase": return Character.isUpperCase(c);
                case "Ll": case "Lower": case "IsLowercase": return Character.isLowerCase(c);
                case "N": case "Nd": case "Digit": case "IsDigit": return Character.isDigit(c);
                case "Alnum": return Character.isLetterOrDigit(c);
                case "Punct": case "P": return (c >= '!' && c <= '/') || (c >= ':' && c <= '@') || (c >= '[' && c <= '`') || (c >= '{' && c <= '~');
                case "Space": case "IsWhite_Space": return Character.isWhitespace(c);
            }
            throw new PatternSyntaxException("Unknown character property name {" + name + "}", name, 0);
        }
        boolean match(Matcher m, int i) { return i < m.to && (test(m.text.charAt(i)) != neg) && matchNext(next, m, i + 1); }
    }
}
