package java.math;
public class BigDecimal extends Number implements Comparable<BigDecimal> {
    private static final long serialVersionUID = 6108874887143696463L;
    private BigInteger intVal;
    private int scale;
    public static final BigDecimal ZERO = new BigDecimal(BigInteger.ZERO, 0);
    public static final BigDecimal ONE = new BigDecimal(BigInteger.ONE, 0);
    public static final BigDecimal TWO = new BigDecimal(BigInteger.TWO, 0);
    public static final BigDecimal TEN = new BigDecimal(BigInteger.TEN, 0);
    public static final int ROUND_UP = 0, ROUND_DOWN = 1, ROUND_CEILING = 2, ROUND_FLOOR = 3, ROUND_HALF_UP = 4, ROUND_HALF_DOWN = 5, ROUND_HALF_EVEN = 6, ROUND_UNNECESSARY = 7;
    private void writeObject(java.io.ObjectOutputStream s) throws java.io.IOException { s.defaultWriteObject(); }
    private void readObject(java.io.ObjectInputStream s) throws java.io.IOException, ClassNotFoundException {
        s.defaultReadObject();
        if (intVal == null) throw new java.io.StreamCorruptedException("BigDecimal: null intVal in stream");
    }
    public BigDecimal(BigInteger unscaledVal, int scale) { this.intVal = unscaledVal; this.scale = scale; }
    public BigDecimal(BigInteger val) { this(val, 0); }
    public BigDecimal(int val) { this(BigInteger.valueOf(val), 0); }
    public BigDecimal(long val) { this(BigInteger.valueOf(val), 0); }
    public BigDecimal(String val) {
        String s = val.trim();
        int e = 0;
        int ei = Math.max(s.indexOf('e'), s.indexOf('E'));
        if (ei >= 0) { e = Integer.parseInt(s.substring(ei + 1).replace("+", "")); s = s.substring(0, ei); }
        int dot = s.indexOf('.');
        int sc = 0;
        if (dot >= 0) { sc = s.length() - dot - 1; s = s.substring(0, dot) + s.substring(dot + 1); }
        if (s.isEmpty() || s.equals("-") || s.equals("+")) throw new NumberFormatException("Character array is missing \"exponent\" mark 'e' or 'E'.");
        BigInteger iv;
        try { iv = new BigInteger(s); } catch (NumberFormatException ex) { throw new NumberFormatException("Character " + s + " is neither a decimal digit number, decimal point, nor \"e\" notation exponential mark."); }
        this.intVal = iv;
        this.scale = sc - e;
    }
    public BigDecimal(double val) {
        if (Double.isInfinite(val) || Double.isNaN(val)) throw new NumberFormatException("Infinite or NaN");
        long bits = Double.doubleToLongBits(val);
        int sign = ((bits >> 63) == 0 ? 1 : -1);
        int exponent = (int) ((bits >> 52) & 0x7ffL);
        long significand = (exponent == 0 ? (bits & ((1L << 52) - 1)) << 1 : (bits & ((1L << 52) - 1)) | (1L << 52));
        exponent -= 1075;
        if (significand == 0) { this.intVal = BigInteger.ZERO; this.scale = 0; return; }
        while ((significand & 1) == 0) { significand >>= 1; exponent++; }
        BigInteger m = BigInteger.valueOf(sign * significand);
        if (exponent >= 0) { this.intVal = m.multiply(BigInteger.TWO.pow(exponent)); this.scale = 0; }
        else { this.intVal = m.multiply(BigInteger.valueOf(5).pow(-exponent)); this.scale = -exponent; }
    }
    public BigDecimal(String v, MathContext mc) { this(new BigDecimal(v).round(mc)); }
    private BigDecimal(BigDecimal o) { this.intVal = o.intVal; this.scale = o.scale; }
    public static BigDecimal valueOf(long val) { return new BigDecimal(BigInteger.valueOf(val), 0); }
    public static BigDecimal valueOf(long unscaledVal, int scale) { return new BigDecimal(BigInteger.valueOf(unscaledVal), scale); }
    public static BigDecimal valueOf(double val) { return new BigDecimal(Double.toString(val)); }
    public int scale() { return scale; }
    public BigInteger unscaledValue() { return intVal; }
    public int signum() { return intVal.signum(); }
    public int precision() { return intVal.signum() == 0 ? 1 : intVal.abs().toString().length(); }
    private static BigInteger pow10(int n) { return BigInteger.TEN.pow(n); }
    private BigInteger scaled(int newScale) { return newScale == scale ? intVal : intVal.multiply(pow10(newScale - scale)); }
    public BigDecimal add(BigDecimal o) { int s = Math.max(scale, o.scale); return new BigDecimal(scaled(s).add(o.scaled(s)), s); }
    public BigDecimal add(BigDecimal o, MathContext mc) { return add(o).round(mc); }
    public BigDecimal subtract(BigDecimal o) { int s = Math.max(scale, o.scale); return new BigDecimal(scaled(s).subtract(o.scaled(s)), s); }
    public BigDecimal subtract(BigDecimal o, MathContext mc) { return subtract(o).round(mc); }
    public BigDecimal multiply(BigDecimal o) { return new BigDecimal(intVal.multiply(o.intVal), scale + o.scale); }
    public BigDecimal multiply(BigDecimal o, MathContext mc) { return multiply(o).round(mc); }
    public BigDecimal negate() { return new BigDecimal(intVal.negate(), scale); }
    public BigDecimal abs() { return signum() < 0 ? negate() : this; }
    public BigDecimal pow(int n) { if (n < 0 || n > 999999999) throw new ArithmeticException("Invalid operation"); return new BigDecimal(intVal.pow(n), scale * n); }
    private static BigInteger divRound(BigInteger num, BigInteger den, RoundingMode mode) {
        BigInteger[] qr = num.divideAndRemainder(den);
        BigInteger q = qr[0], r = qr[1];
        if (r.signum() == 0) return q;
        int sign = num.signum() * den.signum();
        int cmp = r.abs().multiply(BigInteger.TWO).compareTo(den.abs());
        boolean inc;
        switch (mode) {
            case UP: inc = true; break;
            case DOWN: inc = false; break;
            case CEILING: inc = sign > 0; break;
            case FLOOR: inc = sign < 0; break;
            case HALF_UP: inc = cmp >= 0; break;
            case HALF_DOWN: inc = cmp > 0; break;
            case HALF_EVEN: inc = cmp > 0 || (cmp == 0 && q.testBit(0)); break;
            default: throw new ArithmeticException("Rounding necessary");
        }
        return inc ? q.add(BigInteger.valueOf(sign)) : q;
    }
    public BigDecimal setScale(int newScale, RoundingMode mode) {
        if (newScale == scale) return this;
        if (newScale > scale) return new BigDecimal(intVal.multiply(pow10(newScale - scale)), newScale);
        return new BigDecimal(divRound(intVal, pow10(scale - newScale), mode), newScale);
    }
    public BigDecimal setScale(int newScale, int mode) { return setScale(newScale, RoundingMode.values()[mode]); }
    public BigDecimal setScale(int newScale) { return setScale(newScale, RoundingMode.UNNECESSARY); }
    public BigDecimal divide(BigDecimal d, int newScale, RoundingMode mode) {
        if (d.signum() == 0) throw new ArithmeticException(signum() == 0 ? "Division undefined" : "Division by zero");
        // this / d = (iv * 10^-s1) / (dv * 10^-s2) ; resultat avec echelle newScale
        int shift = newScale - scale + d.scale;
        BigInteger num = intVal, den = d.intVal;
        if (shift >= 0) num = num.multiply(pow10(shift)); else den = den.multiply(pow10(-shift));
        return new BigDecimal(divRound(num, den, mode), newScale);
    }
    public BigDecimal divide(BigDecimal d, int newScale, int mode) { return divide(d, newScale, RoundingMode.values()[mode]); }
    public BigDecimal divide(BigDecimal d, RoundingMode mode) { return divide(d, scale, mode); }
    public BigDecimal divide(BigDecimal d) {
        if (d.signum() == 0) throw new ArithmeticException(signum() == 0 ? "Division undefined" : "Division by zero");
        int pref = scale - d.scale;
        if (signum() == 0) return new BigDecimal(BigInteger.ZERO, Math.max(Math.min(pref, Integer.MAX_VALUE), Integer.MIN_VALUE));
        // diviseur : le quotient exact existe s'il n'a que des facteurs 2 et 5
        BigInteger den = d.intVal.abs().divide(d.intVal.abs().gcd(intVal.abs()));
        BigInteger t = den;
        int twos = 0, fives = 0;
        while (!t.testBit(0)) { t = t.shiftRight(1); twos++; }
        BigInteger five = BigInteger.valueOf(5);
        while (t.remainder(five).signum() == 0) { t = t.divide(five); fives++; }
        if (!t.equals(BigInteger.ONE)) throw new ArithmeticException("Non-terminating decimal expansion; no exact representable decimal result.");
        int extra = Math.max(twos, fives);
        BigDecimal q = divide(d, pref + extra, RoundingMode.UNNECESSARY);
        // reduit a l'echelle preferee autant que possible
        while (q.scale > pref && q.intVal.remainder(BigInteger.TEN).signum() == 0) q = new BigDecimal(q.intVal.divide(BigInteger.TEN), q.scale - 1);
        return q;
    }
    public BigDecimal divide(BigDecimal d, MathContext mc) {
        if (mc.precision == 0) return divide(d);
        if (d.signum() == 0) throw new ArithmeticException(signum() == 0 ? "Division undefined" : "Division by zero");
        int pref = scale - d.scale;
        if (signum() == 0) return new BigDecimal(BigInteger.ZERO, pref);
        int guess = mc.precision + 3 + Math.max(0, d.precision() - precision());
        BigDecimal q = divide(d, Math.max(pref, 0) + guess + (precision() < d.precision() ? 0 : 0), RoundingMode.DOWN);
        // calcule avec assez de chiffres puis arrondit
        BigDecimal exact = divide(d, Math.max(pref, 0) + guess + 5, RoundingMode.DOWN);
        BigDecimal r = exact.round(mc);
        // si le resultat est exact, enleve les zeros de fin jusqu'a l'echelle preferee
        BigDecimal back = r.multiply(d);
        if (back.compareTo(this) == 0) { while (r.scale > pref && r.intVal.remainder(BigInteger.TEN).signum() == 0) r = new BigDecimal(r.intVal.divide(BigInteger.TEN), r.scale - 1); }
        return r;
    }
    public BigDecimal remainder(BigDecimal d) { BigDecimal q = divideToIntegralValue(d); return subtract(q.multiply(d)); }
    public BigDecimal divideToIntegralValue(BigDecimal d) { return divide(d, 0, RoundingMode.DOWN); }
    public BigDecimal[] divideAndRemainder(BigDecimal d) { BigDecimal q = divideToIntegralValue(d); return new BigDecimal[] { q, subtract(q.multiply(d)) }; }
    public BigDecimal round(MathContext mc) {
        if (mc.precision == 0) return this;
        int p = precision();
        if (p <= mc.precision) return this;
        int drop = p - mc.precision;
        BigDecimal r = new BigDecimal(divRound(intVal, pow10(drop), mc.roundingMode), scale - drop);
        if (r.precision() > mc.precision) r = new BigDecimal(divRound(r.intVal, BigInteger.TEN, mc.roundingMode), r.scale - 1);
        return r;
    }
    public BigDecimal sqrt(MathContext mc) {
        if (signum() < 0) throw new ArithmeticException("Attempted square root of negative BigDecimal");
        if (signum() == 0) return valueOf(0, scale / 2);
        int prec = mc.precision == 0 ? precision() / 2 + 1 : mc.precision;
        int ws = Math.max(prec + 2, scale);
        BigDecimal v = this.setScale(2 * ws, RoundingMode.DOWN);
        BigDecimal res = new BigDecimal(v.intVal.sqrt(), ws).round(mc);
        if (res.multiply(res).compareTo(this) == 0) res = res.stripTrailingZerosTo(scale / 2);
        return res;
    }
    private BigDecimal stripTrailingZerosTo(int pref) { BigDecimal r = this; while (r.scale > pref && r.intVal.remainder(BigInteger.TEN).signum() == 0) r = new BigDecimal(r.intVal.divide(BigInteger.TEN), r.scale - 1); return r; }
    public BigDecimal stripTrailingZeros() {
        if (signum() == 0) return ZERO;
        BigDecimal r = this;
        while (r.intVal.remainder(BigInteger.TEN).signum() == 0) r = new BigDecimal(r.intVal.divide(BigInteger.TEN), r.scale - 1);
        return r;
    }
    public BigDecimal movePointLeft(int n) { return new BigDecimal(intVal, scale + n).scaleAtLeastZero(); }
    public BigDecimal movePointRight(int n) { return new BigDecimal(intVal, scale - n).scaleAtLeastZero(); }
    private BigDecimal scaleAtLeastZero() { return scale < 0 ? setScale(0, RoundingMode.UNNECESSARY) : this; }
    public BigDecimal scaleByPowerOfTen(int n) { return new BigDecimal(intVal, scale - n); }
    public BigDecimal max(BigDecimal o) { return compareTo(o) >= 0 ? this : o; }
    public BigDecimal min(BigDecimal o) { return compareTo(o) <= 0 ? this : o; }
    public int compareTo(BigDecimal o) { int s = Math.max(scale, o.scale); return scaled(s).compareTo(o.scaled(s)); }
    public boolean equals(Object x) { return x instanceof BigDecimal b && b.scale == scale && b.intVal.equals(intVal); }
    public int hashCode() { return 31 * intVal.hashCode() + scale; }
    public String toString() {
        if (scale == 0) return intVal.toString();
        String digits = intVal.abs().toString();
        long adjusted = -(long) scale + (digits.length() - 1);
        StringBuilder sb = new StringBuilder();
        if (intVal.signum() < 0) sb.append('-');
        if (scale >= 0 && adjusted >= -6) {
            int pad = scale - digits.length();
            if (pad >= 0) { sb.append("0."); for (int i = 0; i < pad; i++) sb.append('0'); sb.append(digits); }
            else { sb.append(digits, 0, -pad); sb.append('.'); sb.append(digits, -pad, digits.length()); }
        } else {
            sb.append(digits.charAt(0));
            if (digits.length() > 1) { sb.append('.'); sb.append(digits, 1, digits.length()); }
            if (adjusted != 0) { sb.append('E'); if (adjusted > 0) sb.append('+'); sb.append(adjusted); }
        }
        return sb.toString();
    }
    public String toPlainString() {
        if (scale == 0) return intVal.toString();
        if (scale < 0) { if (signum() == 0) return "0"; StringBuilder sb = new StringBuilder(intVal.toString()); for (int i = 0; i < -scale; i++) sb.append('0'); return sb.toString(); }
        String digits = intVal.abs().toString();
        StringBuilder sb = new StringBuilder();
        if (intVal.signum() < 0) sb.append('-');
        int pad = scale - digits.length();
        if (pad >= 0) { sb.append("0."); for (int i = 0; i < pad; i++) sb.append('0'); sb.append(digits); }
        else { sb.append(digits, 0, -pad); sb.append('.'); sb.append(digits, -pad, digits.length()); }
        return sb.toString();
    }
    public String toEngineeringString() { return toString(); }
    public BigInteger toBigInteger() { return setScale(0, RoundingMode.DOWN).intVal; }
    public BigInteger toBigIntegerExact() { return setScale(0, RoundingMode.UNNECESSARY).intVal; }
    public int intValue() { return toBigInteger().intValue(); }
    public long longValue() { return toBigInteger().longValue(); }
    public int intValueExact() { return toBigIntegerExact().intValueExact(); }
    public long longValueExact() { return toBigIntegerExact().longValueExact(); }
    public double doubleValue() { return Double.parseDouble(toString()); }
    public float floatValue() { return (float) doubleValue(); }
    public BigDecimal ulp() { return new BigDecimal(BigInteger.ONE, scale); }
}
