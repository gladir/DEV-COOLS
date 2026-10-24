package java.util;
public class BitSet implements Cloneable, java.io.Serializable {
    private long[] words = new long[1];
    public BitSet() {}
    public BitSet(int nbits) { words = new long[Math.max(1, (nbits + 63) >> 6)]; }
    private void ensure(int w) { if (w >= words.length) words = Arrays.copyOf(words, Math.max(words.length * 2, w + 1)); }
    public void set(int i) { ensure(i >> 6); words[i >> 6] |= 1L << i; }
    public void set(int i, boolean v) { if (v) set(i); else clear(i); }
    public void set(int from, int to) { for (int i = from; i < to; i++) set(i); }
    public void clear(int i) { if ((i >> 6) < words.length) words[i >> 6] &= ~(1L << i); }
    public void clear() { words = new long[1]; }
    public void flip(int i) { ensure(i >> 6); words[i >> 6] ^= 1L << i; }
    public boolean get(int i) { return (i >> 6) < words.length && (words[i >> 6] & (1L << i)) != 0; }
    public int cardinality() { int c = 0; for (long w : words) c += Long.bitCount(w); return c; }
    public int length() { for (int i = words.length - 1; i >= 0; i--) if (words[i] != 0) return i * 64 + 64 - Long.numberOfLeadingZeros(words[i]); return 0; }
    public int size() { return words.length * 64; }
    public boolean isEmpty() { return length() == 0; }
    public int nextSetBit(int from) { for (int i = from; i < words.length * 64; i++) if (get(i)) return i; return -1; }
    public int nextClearBit(int from) { int i = from; while (get(i)) i++; return i; }
    public void and(BitSet o) { for (int i = 0; i < words.length; i++) words[i] &= i < o.words.length ? o.words[i] : 0; }
    public void or(BitSet o) { ensure(o.words.length - 1); for (int i = 0; i < o.words.length; i++) words[i] |= o.words[i]; }
    public void xor(BitSet o) { ensure(o.words.length - 1); for (int i = 0; i < o.words.length; i++) words[i] ^= o.words[i]; }
    public void andNot(BitSet o) { for (int i = 0; i < Math.min(words.length, o.words.length); i++) words[i] &= ~o.words[i]; }
    public boolean equals(Object o) { return o instanceof BitSet b && toString().equals(b.toString()); }
    public int hashCode() { long h = 1234; for (int i = words.length; --i >= 0; ) h ^= words[i] * (i + 1); return (int) ((h >> 32) ^ h); }
    public Object clone() { BitSet b = new BitSet(); b.words = words.clone(); return b; }
    public String toString() {
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (int i = nextSetBit(0); i >= 0; i = nextSetBit(i + 1)) { if (!first) sb.append(", "); first = false; sb.append(i); }
        return sb.append('}').toString();
    }
}
