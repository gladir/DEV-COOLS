package java.math;
import java.util.Random;
public class BigInteger extends Number implements Comparable<BigInteger> {
    private static final long serialVersionUID = -8287574255936472291L;
    static final int BASE = 1000000000;
    int signum;
    int[] mag; // little-endian, base 1e9, sans zeros de tete
    private static final java.io.ObjectStreamField[] serialPersistentFields = {
        new java.io.ObjectStreamField("signum", Integer.TYPE),
        new java.io.ObjectStreamField("magnitude", byte[].class),
        new java.io.ObjectStreamField("bitCount", Integer.TYPE),
        new java.io.ObjectStreamField("bitLength", Integer.TYPE),
        new java.io.ObjectStreamField("firstNonzeroByteNum", Integer.TYPE),
        new java.io.ObjectStreamField("lowestSetBit", Integer.TYPE)
    };
    private static int[] limbsOf(byte[] magnitude) {
        int[] limbs = new int[magnitude.length * 8 / 29 + 2];
        int n = 0;
        for (byte bb : magnitude) {
            long carry = bb & 255;
            for (int j = 0; j < n; j++) {
                long v = (long) limbs[j] * 256 + carry;
                limbs[j] = (int) (v % BASE);
                carry = v / BASE;
            }
            while (carry != 0) { limbs[n++] = (int) (carry % BASE); carry /= BASE; }
        }
        return java.util.Arrays.copyOf(limbs, n);
    }
    public BigInteger(int signum, byte[] magnitude) {
        if (signum < -1 || signum > 1) throw new NumberFormatException("Invalid signum value");
        int[] m = limbsOf(magnitude);
        if (m.length == 0) { this.mag = m; this.signum = 0; }
        else {
            if (signum == 0) throw new NumberFormatException("signum-magnitude mismatch");
            this.mag = m; this.signum = signum;
        }
    }
    private static BigInteger fromTwos(byte[] val) {
        if (val.length == 0) throw new NumberFormatException("Zero length BigInteger");
        BigInteger u = new BigInteger(1, val);
        if (val[0] < 0) u = u.subtract(ONE.shiftLeft(8 * val.length));
        return u;
    }
    public BigInteger(byte[] val) { this(fromTwos(val)); }
    private BigInteger(BigInteger o) { this.mag = o.mag; this.signum = o.signum; }
    private byte[] magSerializedForm() {
        if (signum == 0) return new byte[0];
        byte[] b = abs().toByteArray();
        if (b.length > 1 && b[0] == 0) b = java.util.Arrays.copyOfRange(b, 1, b.length);
        return b;
    }
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException {
        java.io.ObjectOutputStream.PutField fields = s.putFields();
        fields.put("signum", signum);
        fields.put("magnitude", magSerializedForm());
        fields.put("bitCount", -1);
        fields.put("bitLength", -1);
        fields.put("lowestSetBit", -2);
        fields.put("firstNonzeroByteNum", -2);
        s.writeFields();
    }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        java.io.ObjectInputStream.GetField fields = s.readFields();
        int sign = fields.get("signum", -2);
        byte[] magnitude = (byte[]) fields.get("magnitude", null);
        if (sign < -1 || sign > 1) throw new java.io.StreamCorruptedException("BigInteger: Invalid signum value");
        int[] m = limbsOf(magnitude);
        if ((m.length == 0) != (sign == 0)) throw new java.io.StreamCorruptedException("BigInteger: signum-magnitude mismatch");
        this.mag = m;
        this.signum = sign;
    }
    public static final BigInteger ZERO = new BigInteger(0, new int[0]);
    public static final BigInteger ONE = valueOf(1);
    public static final BigInteger TWO = valueOf(2);
    public static final BigInteger TEN = valueOf(10);
    BigInteger(int signum, int[] mag) {
        int n = mag.length;
        while (n > 0 && mag[n - 1] == 0) n--;
        if (n != mag.length) mag = java.util.Arrays.copyOf(mag, n);
        this.mag = mag;
        this.signum = n == 0 ? 0 : signum;
    }
    public BigInteger(String val) { this(val, 10); }
    public BigInteger(String val, int radix) {
        if (val.isEmpty()) throw new NumberFormatException("Zero length BigInteger");
        int i = 0, sg = 1;
        char c0 = val.charAt(0);
        if (c0 == '-') { sg = -1; i = 1; } else if (c0 == '+') i = 1;
        if (i >= val.length()) throw new NumberFormatException("Zero length BigInteger");
        BigInteger r = ZERO;
        if (radix == 10) {
            int len = val.length() - i;
            for (int k = i; k < val.length(); k++) if (val.charAt(k) < '0' || val.charAt(k) > '9') throw new NumberFormatException("For input string: \"" + val + "\"");
            int words = (len + 8) / 9;
            int[] m = new int[words];
            int pos = val.length();
            for (int w = 0; w < words; w++) {
                int st = Math.max(i, pos - 9);
                m[w] = Integer.parseInt(val.substring(st, pos));
                pos = st;
            }
            BigInteger t = new BigInteger(sg, m);
            this.mag = t.mag; this.signum = t.signum;
            return;
        }
        BigInteger rd = valueOf(radix);
        for (; i < val.length(); i++) {
            int d = Character.digit(val.charAt(i), radix);
            if (d < 0) throw new NumberFormatException("For input string: \"" + val + "\"");
            r = r.multiply(rd).add(valueOf(d));
        }
        this.mag = r.mag; this.signum = r.signum == 0 ? 0 : sg;
    }
    public BigInteger(int numBits, Random rnd) {
        BigInteger r = ZERO;
        for (int i = 0; i < numBits; i++) r = r.shiftLeft(1).add(rnd.nextBoolean() ? ONE : ZERO);
        this.mag = r.mag; this.signum = r.signum;
    }
    public static BigInteger valueOf(long v) {
        if (v == 0) return ZERO == null ? new BigInteger(0, new int[0]) : ZERO;
        int sg = v < 0 ? -1 : 1;
        int[] m = new int[3];
        int n = 0;
        if (v == Long.MIN_VALUE) { return new BigInteger("-9223372036854775808"); }
        long a = v < 0 ? -v : v;
        while (a != 0) { m[n++] = (int) (a % BASE); a /= BASE; }
        return new BigInteger(sg, java.util.Arrays.copyOf(m, n));
    }
    public static BigInteger probablePrime(int bits, Random rnd) {
        while (true) { BigInteger c = new BigInteger(bits, rnd).setBit(bits - 1).setBit(0); if (c.isProbablePrime(20)) return c; }
    }
    private static int cmpMag(int[] a, int[] b) {
        if (a.length != b.length) return a.length < b.length ? -1 : 1;
        for (int i = a.length - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
        return 0;
    }
    private static int[] addMag(int[] a, int[] b) {
        if (a.length < b.length) { int[] t = a; a = b; b = t; }
        int[] r = new int[a.length + 1];
        int carry = 0;
        for (int i = 0; i < a.length; i++) {
            int s = a[i] + (i < b.length ? b[i] : 0) + carry;
            if (s >= BASE) { s -= BASE; carry = 1; } else carry = 0;
            r[i] = s;
        }
        r[a.length] = carry;
        return r;
    }
    private static int[] subMag(int[] a, int[] b) { // a >= b
        int[] r = new int[a.length];
        int borrow = 0;
        for (int i = 0; i < a.length; i++) {
            int s = a[i] - (i < b.length ? b[i] : 0) - borrow;
            if (s < 0) { s += BASE; borrow = 1; } else borrow = 0;
            r[i] = s;
        }
        return r;
    }
    public BigInteger add(BigInteger o) {
        if (o.signum == 0) return this;
        if (signum == 0) return o;
        if (signum == o.signum) return new BigInteger(signum, addMag(mag, o.mag));
        int c = cmpMag(mag, o.mag);
        if (c == 0) return ZERO;
        return c > 0 ? new BigInteger(signum, subMag(mag, o.mag)) : new BigInteger(o.signum, subMag(o.mag, mag));
    }
    public BigInteger negate() { return new BigInteger(-signum, mag); }
    public BigInteger subtract(BigInteger o) { return add(o.negate()); }
    public BigInteger abs() { return signum >= 0 ? this : negate(); }
    public int signum() { return signum; }
    public BigInteger multiply(BigInteger o) {
        if (signum == 0 || o.signum == 0) return ZERO;
        int[] a = mag, b = o.mag;
        long[] r = new long[a.length + b.length + 1];
        for (int i = 0; i < a.length; i++) {
            long carry = 0;
            long ai = a[i];
            for (int j = 0; j < b.length; j++) {
                long cur = r[i + j] + ai * b[j] + carry;
                carry = cur / BASE;
                r[i + j] = cur % BASE;
            }
            int k = i + b.length;
            while (carry != 0) { long cur = r[k] + carry; carry = cur / BASE; r[k] = cur % BASE; k++; }
        }
        int[] m = new int[r.length];
        for (int i = 0; i < r.length; i++) m[i] = (int) r[i];
        return new BigInteger(signum * o.signum, m);
    }
    // division de magnitudes : retourne {quotient, reste}
    private static int[][] divMag(int[] a, int[] b) {
        if (cmpMag(a, b) < 0) return new int[][] { new int[0], a };
        if (b.length == 1) {
            int[] q = new int[a.length];
            long rem = 0;
            for (int i = a.length - 1; i >= 0; i--) { long cur = rem * BASE + a[i]; q[i] = (int) (cur / b[0]); rem = cur % b[0]; }
            return new int[][] { q, rem == 0 ? new int[0] : new int[] { (int) rem } };
        }
        // Knuth D, base 1e9
        int n = b.length, m = a.length - n;
        long d = BASE / (b[n - 1] + 1);
        int[] u = new int[a.length + 1], v = new int[n];
        long carry = 0;
        for (int i = 0; i < a.length; i++) { long cur = (long) a[i] * d + carry; u[i] = (int) (cur % BASE); carry = cur / BASE; }
        u[a.length] = (int) carry;
        carry = 0;
        for (int i = 0; i < n; i++) { long cur = (long) b[i] * d + carry; v[i] = (int) (cur % BASE); carry = cur / BASE; }
        int[] q = new int[m + 1];
        for (int j = m; j >= 0; j--) {
            long num = (long) u[j + n] * BASE + u[j + n - 1];
            long qhat = num / v[n - 1];
            long rhat = num % v[n - 1];
            while (qhat >= BASE || qhat * v[n - 2] > rhat * BASE + u[j + n - 2]) {
                qhat--; rhat += v[n - 1];
                if (rhat >= BASE) break;
            }
            long borrow = 0, carry2 = 0;
            for (int i = 0; i < n; i++) {
                long p = qhat * v[i] + carry2;
                carry2 = p / BASE;
                long sub = u[i + j] - (p % BASE) - borrow;
                if (sub < 0) { sub += BASE; borrow = 1; } else borrow = 0;
                u[i + j] = (int) sub;
            }
            long sub = u[j + n] - carry2 - borrow;
            if (sub < 0) { sub += BASE; borrow = 1; } else borrow = 0;
            u[j + n] = (int) sub;
            if (borrow != 0) {
                qhat--;
                long c2 = 0;
                for (int i = 0; i < n; i++) {
                    long s = (long) u[i + j] + v[i] + c2;
                    if (s >= BASE) { s -= BASE; c2 = 1; } else c2 = 0;
                    u[i + j] = (int) s;
                }
                u[j + n] = (int) (((long) u[j + n] + c2) % BASE);
            }
            q[j] = (int) qhat;
        }
        int[] r = new int[n];
        long rem = 0;
        for (int i = n - 1; i >= 0; i--) { long cur = rem * BASE + u[i]; r[i] = (int) (cur / d); rem = cur % d; }
        return new int[][] { q, r };
    }
    public BigInteger[] divideAndRemainder(BigInteger o) {
        if (o.signum == 0) throw new ArithmeticException("BigInteger divide by zero");
        int[][] qr = divMag(mag, o.mag);
        return new BigInteger[] { new BigInteger(signum * o.signum, qr[0]), new BigInteger(signum, qr[1]) };
    }
    public BigInteger divide(BigInteger o) { return divideAndRemainder(o)[0]; }
    public BigInteger remainder(BigInteger o) { return divideAndRemainder(o)[1]; }
    public BigInteger mod(BigInteger m) {
        if (m.signum <= 0) throw new ArithmeticException("BigInteger: modulus not positive");
        BigInteger r = remainder(m);
        return r.signum >= 0 ? r : r.add(m);
    }
    public BigInteger pow(int e) {
        if (e < 0) throw new ArithmeticException("Negative exponent");
        BigInteger r = ONE, b = this;
        while (e > 0) { if ((e & 1) != 0) r = r.multiply(b); e >>= 1; if (e > 0) b = b.multiply(b); }
        return r;
    }
    public BigInteger modPow(BigInteger e, BigInteger m) {
        if (m.signum <= 0) throw new ArithmeticException("BigInteger: modulus not positive");
        if (e.signum < 0) return modInverse(m).modPow(e.negate(), m);
        BigInteger r = ONE.mod(m), b = this.mod(m);
        String bits = e.toString(2);
        for (int i = 0; i < bits.length(); i++) {
            r = r.multiply(r).mod(m);
            if (bits.charAt(i) == '1') r = r.multiply(b).mod(m);
        }
        return r;
    }
    public BigInteger modInverse(BigInteger m) {
        if (m.signum <= 0) throw new ArithmeticException("BigInteger: modulus not positive");
        BigInteger a = this.mod(m), b = m, x0 = ONE, x1 = ZERO;
        while (b.signum != 0) { BigInteger[] qr = a.divideAndRemainder(b); a = b; b = qr[1]; BigInteger t = x0.subtract(qr[0].multiply(x1)); x0 = x1; x1 = t; }
        if (!a.equals(ONE)) throw new ArithmeticException("BigInteger not invertible.");
        return x0.mod(m);
    }
    public BigInteger gcd(BigInteger o) {
        BigInteger a = abs(), b = o.abs();
        while (b.signum != 0) { BigInteger t = a.remainder(b); a = b; b = t; }
        return a;
    }
    public BigInteger sqrt() {
        if (signum < 0) throw new ArithmeticException("Negative BigInteger");
        if (signum == 0) return ZERO;
        BigInteger x = ONE.shiftLeft((bitLength() + 1) / 2);
        while (true) { BigInteger y = x.add(divide(x)).shiftRight(1); if (y.compareTo(x) >= 0) return x; x = y; }
    }
    public boolean isProbablePrime(int certainty) {
        BigInteger n = abs();
        if (n.compareTo(TWO) < 0) return false;
        int[] small = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37 };
        for (int p : small) { BigInteger bp = valueOf(p); if (n.equals(bp)) return true; if (n.remainder(bp).signum == 0) return false; }
        BigInteger d = n.subtract(ONE);
        int s = 0;
        while (!d.testBit(0)) { d = d.shiftRight(1); s++; }
        for (int p : small) {
            BigInteger x = valueOf(p).modPow(d, n);
            if (x.equals(ONE) || x.equals(n.subtract(ONE))) continue;
            boolean comp = true;
            for (int r = 1; r < s; r++) { x = x.multiply(x).mod(n); if (x.equals(n.subtract(ONE))) { comp = false; break; } }
            if (comp) return false;
        }
        return true;
    }
    public BigInteger nextProbablePrime() { BigInteger c = add(ONE); while (!c.isProbablePrime(20)) c = c.add(ONE); return c; }
    public BigInteger shiftLeft(int n) { if (n < 0) return shiftRight(-n); return multiply(TWO.pow(n)); }
    public BigInteger shiftRight(int n) {
        if (n < 0) return shiftLeft(-n);
        BigInteger p = TWO.pow(n);
        BigInteger[] qr = divideAndRemainder(p);
        return (signum < 0 && qr[1].signum != 0) ? qr[0].subtract(ONE) : qr[0];
    }
    public boolean testBit(int n) { return shiftRight(n).mod(TWO).signum != 0; }
    public BigInteger setBit(int n) { return testBit(n) ? this : add(TWO.pow(n)); }
    public BigInteger clearBit(int n) { return testBit(n) ? subtract(TWO.pow(n)) : this; }
    public BigInteger flipBit(int n) { return testBit(n) ? clearBit(n) : setBit(n); }
    public int bitLength() {
        if (signum == 0) return 0;
        BigInteger a = signum < 0 ? negate().subtract(ONE) : this;
        if (a.signum == 0) return 0;
        return a.toString(2).length();
    }
    public int bitCount() {
        BigInteger a = signum < 0 ? negate().subtract(ONE) : this;
        String s = a.signum == 0 ? "" : a.toString(2);
        int c = 0;
        for (int i = 0; i < s.length(); i++) if (s.charAt(i) == '1') c++;
        return c;
    }
    public int getLowestSetBit() { if (signum == 0) return -1; int i = 0; while (!testBit(i)) i++; return i; }
    private static BigInteger bitop(BigInteger a, BigInteger b, int op) {
        int n = Math.max(a.bitLength(), b.bitLength()) + 1;
        BigInteger mod = TWO.pow(n);
        BigInteger x = a.mod(mod), y = b.mod(mod), r = ZERO, bit = ONE;
        String xs = pad(x.toString(2), n), ys = pad(y.toString(2), n);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < n; i++) {
            boolean p = xs.charAt(i) == '1', q = ys.charAt(i) == '1';
            boolean v = op == 0 ? (p & q) : op == 1 ? (p | q) : (p ^ q);
            sb.append(v ? '1' : '0');
        }
        BigInteger res = new BigInteger(sb.toString(), 2);
        if (sb.charAt(0) == '1') res = res.subtract(mod);
        return res;
    }
    private static String pad(String s, int n) { StringBuilder sb = new StringBuilder(); for (int i = s.length(); i < n; i++) sb.append('0'); return sb.append(s).toString(); }
    public BigInteger and(BigInteger o) { return bitop(this, o, 0); }
    public BigInteger or(BigInteger o) { return bitop(this, o, 1); }
    public BigInteger xor(BigInteger o) { return bitop(this, o, 2); }
    public BigInteger not() { return negate().subtract(ONE); }
    public BigInteger andNot(BigInteger o) { return and(o.not()); }
    public BigInteger min(BigInteger o) { return compareTo(o) < 0 ? this : o; }
    public BigInteger max(BigInteger o) { return compareTo(o) > 0 ? this : o; }
    public int compareTo(BigInteger o) {
        if (signum != o.signum) return signum > o.signum ? 1 : -1;
        int c = cmpMag(mag, o.mag);
        return signum >= 0 ? c : -c;
    }
    public boolean equals(Object x) { return x instanceof BigInteger b && b.signum == signum && cmpMag(mag, b.mag) == 0; }
    public int hashCode() { int h = 0; for (int i = mag.length - 1; i >= 0; i--) h = 31 * h + mag[i]; return h * signum; }
    public String toString() {
        if (signum == 0) return "0";
        StringBuilder sb = new StringBuilder();
        if (signum < 0) sb.append('-');
        sb.append(mag[mag.length - 1]);
        for (int i = mag.length - 2; i >= 0; i--) { String s = Integer.toString(mag[i]); for (int k = s.length(); k < 9; k++) sb.append('0'); sb.append(s); }
        return sb.toString();
    }
    public String toString(int radix) {
        if (radix == 10 || radix < 2 || radix > 36) return toString();
        if (signum == 0) return "0";
        StringBuilder sb = new StringBuilder();
        BigInteger n = abs(), r = valueOf(radix);
        int chunk = 1;
        long cr = radix;
        while (cr * radix < 1000000000L) { cr *= radix; chunk++; }
        BigInteger big = valueOf(cr);
        while (n.signum != 0) {
            BigInteger[] qr = n.divideAndRemainder(big);
            long rem = qr[1].longValue();
            n = qr[0];
            for (int k = 0; k < chunk; k++) {
                if (n.signum == 0 && rem == 0) break;
                sb.append(Character.forDigit((int) (rem % radix), radix));
                rem /= radix;
            }
        }
        if (signum < 0) sb.append('-');
        return sb.reverse().toString();
    }
    public int intValue() { return (int) longValue(); }
    public long longValue() {
        long r = 0;
        for (int i = mag.length - 1; i >= 0; i--) r = r * BASE + mag[i];
        return signum < 0 ? -r : r;
    }
    public double doubleValue() {
        double r = 0;
        for (int i = mag.length - 1; i >= 0; i--) r = r * BASE + mag[i];
        return signum < 0 ? -r : r;
    }
    public float floatValue() { return (float) doubleValue(); }
    public long longValueExact() { if (bitLength() > 63) throw new ArithmeticException("BigInteger out of long range"); return longValue(); }
    public int intValueExact() { if (bitLength() > 31) throw new ArithmeticException("BigInteger out of int range"); return intValue(); }
    public byte[] toByteArray() {
        int n = bitLength() / 8 + 1;
        byte[] b = new byte[n];
        BigInteger v = this;
        BigInteger m256 = valueOf(256);
        for (int i = n - 1; i >= 0; i--) { b[i] = (byte) v.mod(m256).intValue(); v = v.shiftRight(8); }
        return b;
    }
}
