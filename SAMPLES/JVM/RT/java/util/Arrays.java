package java.util;
import java.util.function.*;
import java.util.stream.*;
public final class Arrays {
    private Arrays() {}
    static void rangeCheck(int length, int from, int to) {
        if (from > to) throw new IllegalArgumentException("fromIndex(" + from + ") > toIndex(" + to + ")");
        if (from < 0) throw new ArrayIndexOutOfBoundsException("Array index out of range: " + from);
        if (to > length) throw new ArrayIndexOutOfBoundsException("Array index out of range: " + to);
    }
    public static <T> List<T> asList(T... a) { return new ArrayAsList<>(a); }
    private static class ArrayAsList<E> extends AbstractList<E> implements RandomAccess, java.io.Serializable {
        private final E[] a;
        ArrayAsList(E[] array) { a = Objects.requireNonNull(array); }
        public int size() { return a.length; }
        public Object[] toArray() { return Arrays.copyOf(a, a.length, Object[].class); }
        public E get(int index) { return a[index]; }
        public E set(int index, E element) { E oldValue = a[index]; a[index] = element; return oldValue; }
        public int indexOf(Object o) {
            for (int i = 0; i < a.length; i++) if (Objects.equals(o, a[i])) return i;
            return -1;
        }
        public boolean contains(Object o) { return indexOf(o) >= 0; }
        public void forEach(Consumer<? super E> action) { for (E e : a) action.accept(e); }
        public void replaceAll(UnaryOperator<E> operator) { for (int i = 0; i < a.length; i++) a[i] = operator.apply(a[i]); }
        public void sort(Comparator<? super E> c) { Arrays.sort(a, c); }
    }
    public static <T> T[] copyOf(T[] original, int newLength) {
        T[] copy = (T[]) java.lang.reflect.Array.newInstance(original.getClass().getComponentType(), newLength);
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static <T, U> T[] copyOf(U[] original, int newLength, Class<? extends T[]> newType) {
        T[] copy = (T[]) java.lang.reflect.Array.newInstance(newType.getComponentType(), newLength);
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static <T> T[] copyOfRange(T[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        T[] copy = (T[]) java.lang.reflect.Array.newInstance(original.getClass().getComponentType(), newLength);
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static <T> void sort(T[] a) { sort(a, 0, a.length, null); }
    public static <T> void sort(T[] a, Comparator<? super T> c) { sort(a, 0, a.length, c); }
    public static <T> void sort(T[] a, int from, int to, Comparator<? super T> c) {
        rangeCheck(a.length, from, to);
        int n = to - from;
        if (n < 2) return;
        Object[] src = new Object[n];
        System.arraycopy(a, from, src, 0, n);
        Object[] tmp = new Object[n];
        msort(src, tmp, 0, n, (Comparator<Object>) c);
        System.arraycopy(src, 0, a, from, n);
    }
    private static int cmpObj(Object x, Object y, Comparator<Object> c) {
        return c != null ? c.compare(x, y) : ((Comparable<Object>) x).compareTo(y);
    }
    private static void msort(Object[] a, Object[] tmp, int lo, int hi, Comparator<Object> c) {
        int n = hi - lo;
        if (n < 7) {
            for (int i = lo + 1; i < hi; i++) {
                Object x = a[i];
                int j = i - 1;
                while (j >= lo && cmpObj(a[j], x, c) > 0) { a[j + 1] = a[j]; j--; }
                a[j + 1] = x;
            }
            return;
        }
        int mid = (lo + hi) >>> 1;
        msort(a, tmp, lo, mid, c);
        msort(a, tmp, mid, hi, c);
        if (cmpObj(a[mid - 1], a[mid], c) <= 0) return;
        int i = lo, j = mid, k = lo;
        while (i < mid && j < hi) tmp[k++] = cmpObj(a[j], a[i], c) < 0 ? a[j++] : a[i++];
        while (i < mid) tmp[k++] = a[i++];
        while (j < hi) tmp[k++] = a[j++];
        System.arraycopy(tmp, lo, a, lo, n);
    }
    public static <T> void parallelSort(T[] a, Comparator<? super T> c) { sort(a, c); }
    public static <T> int binarySearch(T[] a, T key, Comparator<? super T> c) { return binarySearch(a, 0, a.length, key, c); }
    public static <T> int binarySearch(T[] a, int from, int to, T key, Comparator<? super T> c) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            int cmp = cmpObj(a[mid], key, (Comparator<Object>) c);
            if (cmp < 0) low = mid + 1; else if (cmp > 0) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static int binarySearch(Object[] a, Object key) { return binarySearch(a, 0, a.length, key, null); }
    public static boolean equals(Object[] a, Object[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (!Objects.equals(a[i], a2[i])) return false;
        return true;
    }
    public static boolean deepEquals(Object[] a1, Object[] a2) {
        if (a1 == a2) return true;
        if (a1 == null || a2 == null) return false;
        int length = a1.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) {
            Object e1 = a1[i], e2 = a2[i];
            if (e1 == e2) continue;
            if (e1 == null) return false;
            boolean eq = deepEquals0(e1, e2);
            if (!eq) return false;
        }
        return true;
    }
    static boolean deepEquals0(Object e1, Object e2) {
        if (e1 instanceof Object[] && e2 instanceof Object[]) return deepEquals((Object[]) e1, (Object[]) e2);
        else if (e1 instanceof byte[] && e2 instanceof byte[]) return equals((byte[]) e1, (byte[]) e2);
        else if (e1 instanceof short[] && e2 instanceof short[]) return equals((short[]) e1, (short[]) e2);
        else if (e1 instanceof int[] && e2 instanceof int[]) return equals((int[]) e1, (int[]) e2);
        else if (e1 instanceof long[] && e2 instanceof long[]) return equals((long[]) e1, (long[]) e2);
        else if (e1 instanceof char[] && e2 instanceof char[]) return equals((char[]) e1, (char[]) e2);
        else if (e1 instanceof float[] && e2 instanceof float[]) return equals((float[]) e1, (float[]) e2);
        else if (e1 instanceof double[] && e2 instanceof double[]) return equals((double[]) e1, (double[]) e2);
        else if (e1 instanceof boolean[] && e2 instanceof boolean[]) return equals((boolean[]) e1, (boolean[]) e2);
        else return e1.equals(e2);
    }
    public static int hashCode(Object[] a) {
        if (a == null) return 0;
        int result = 1;
        for (Object element : a) result = 31 * result + (element == null ? 0 : element.hashCode());
        return result;
    }
    public static int deepHashCode(Object[] a) {
        if (a == null) return 0;
        int result = 1;
        for (Object element : a) {
            int h = 0;
            if (element instanceof Object[]) h = deepHashCode((Object[]) element);
            else if (element instanceof int[]) h = hashCode((int[]) element);
            else if (element instanceof long[]) h = hashCode((long[]) element);
            else if (element instanceof double[]) h = hashCode((double[]) element);
            else if (element instanceof char[]) h = hashCode((char[]) element);
            else if (element instanceof byte[]) h = hashCode((byte[]) element);
            else if (element != null) h = element.hashCode();
            result = 31 * result + h;
        }
        return result;
    }
    public static String toString(Object[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(String.valueOf(a[i]));
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static String deepToString(Object[] a) {
        if (a == null) return "null";
        StringBuilder buf = new StringBuilder();
        deepToString(a, buf, new ArrayList<Object[]>());
        return buf.toString();
    }
    private static void deepToString(Object[] a, StringBuilder buf, List<Object[]> dejaVu) {
        if (a == null) { buf.append("null"); return; }
        int bufLen = buf.length();
        dejaVu.add(a);
        buf.append('[');
        for (int i = 0; i < a.length; i++) {
            if (i != 0) buf.append(", ");
            Object element = a[i];
            if (element == null) buf.append("null");
            else if (element instanceof Object[]) {
                boolean seen = false;
                for (Object[] d : dejaVu) if (d == element) seen = true;
                if (seen) buf.append("[...]"); else deepToString((Object[]) element, buf, dejaVu);
            }
            else if (element instanceof byte[]) buf.append(toString((byte[]) element));
            else if (element instanceof short[]) buf.append(toString((short[]) element));
            else if (element instanceof int[]) buf.append(toString((int[]) element));
            else if (element instanceof long[]) buf.append(toString((long[]) element));
            else if (element instanceof char[]) buf.append(toString((char[]) element));
            else if (element instanceof float[]) buf.append(toString((float[]) element));
            else if (element instanceof double[]) buf.append(toString((double[]) element));
            else if (element instanceof boolean[]) buf.append(toString((boolean[]) element));
            else buf.append(element.toString());
        }
        buf.append(']');
        dejaVu.remove(dejaVu.size() - 1);
    }
    public static void fill(Object[] a, Object val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(Object[] a, int from, int to, Object val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static <T> void setAll(T[] array, IntFunction<? extends T> generator) { for (int i = 0; i < array.length; i++) array[i] = generator.apply(i); }
    public static <T> Stream<T> stream(T[] array) { return Stream.of(array); }
    public static <T> Stream<T> stream(T[] array, int from, int to) { return Stream.of(copyOfRange(array, from, to)); }
    public static void sort(int[] a) { sort(a, 0, a.length); }
    public static void sort(int[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortInt(a, from, to - 1);
    }
    public static void parallelSort(int[] a) { sort(a); }
    private static void qsortInt(int[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            int pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (a[i] < pv) i++;
                while (a[j] > pv) j--;
                if (i <= j) { int t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortInt(a, lo, j); lo = i; } else { qsortInt(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            int x = a[i];
            int j = i - 1;
            while (j >= lo && a[j] > x) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(int[] a, int key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(int[] a, int from, int to, int key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            int midVal = a[mid];
            if (midVal < key) low = mid + 1; else if (midVal > key) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static int[] copyOf(int[] original, int newLength) {
        int[] copy = new int[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static int[] copyOfRange(int[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        int[] copy = new int[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(int[] a, int[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (a[i] != a2[i]) return false;
        return true;
    }
    public static int hashCode(int[] a) {
        if (a == null) return 0;
        int result = 1;
        for (int element : a) result = 31 * result + (element);
        return result;
    }
    public static String toString(int[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(int[] a, int val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(int[] a, int from, int to, int val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void sort(long[] a) { sort(a, 0, a.length); }
    public static void sort(long[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortLong(a, from, to - 1);
    }
    public static void parallelSort(long[] a) { sort(a); }
    private static void qsortLong(long[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            long pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (a[i] < pv) i++;
                while (a[j] > pv) j--;
                if (i <= j) { long t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortLong(a, lo, j); lo = i; } else { qsortLong(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            long x = a[i];
            int j = i - 1;
            while (j >= lo && a[j] > x) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(long[] a, long key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(long[] a, int from, int to, long key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            long midVal = a[mid];
            if (midVal < key) low = mid + 1; else if (midVal > key) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static long[] copyOf(long[] original, int newLength) {
        long[] copy = new long[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static long[] copyOfRange(long[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        long[] copy = new long[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(long[] a, long[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (a[i] != a2[i]) return false;
        return true;
    }
    public static int hashCode(long[] a) {
        if (a == null) return 0;
        int result = 1;
        for (long element : a) result = 31 * result + ((int) (element ^ (element >>> 32)));
        return result;
    }
    public static String toString(long[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(long[] a, long val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(long[] a, int from, int to, long val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void sort(short[] a) { sort(a, 0, a.length); }
    public static void sort(short[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortShort(a, from, to - 1);
    }
    public static void parallelSort(short[] a) { sort(a); }
    private static void qsortShort(short[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            short pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (a[i] < pv) i++;
                while (a[j] > pv) j--;
                if (i <= j) { short t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortShort(a, lo, j); lo = i; } else { qsortShort(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            short x = a[i];
            int j = i - 1;
            while (j >= lo && a[j] > x) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(short[] a, short key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(short[] a, int from, int to, short key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            short midVal = a[mid];
            if (midVal < key) low = mid + 1; else if (midVal > key) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static short[] copyOf(short[] original, int newLength) {
        short[] copy = new short[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static short[] copyOfRange(short[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        short[] copy = new short[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(short[] a, short[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (a[i] != a2[i]) return false;
        return true;
    }
    public static int hashCode(short[] a) {
        if (a == null) return 0;
        int result = 1;
        for (short element : a) result = 31 * result + (element);
        return result;
    }
    public static String toString(short[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(short[] a, short val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(short[] a, int from, int to, short val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void sort(char[] a) { sort(a, 0, a.length); }
    public static void sort(char[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortChar(a, from, to - 1);
    }
    public static void parallelSort(char[] a) { sort(a); }
    private static void qsortChar(char[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            char pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (a[i] < pv) i++;
                while (a[j] > pv) j--;
                if (i <= j) { char t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortChar(a, lo, j); lo = i; } else { qsortChar(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            char x = a[i];
            int j = i - 1;
            while (j >= lo && a[j] > x) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(char[] a, char key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(char[] a, int from, int to, char key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            char midVal = a[mid];
            if (midVal < key) low = mid + 1; else if (midVal > key) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static char[] copyOf(char[] original, int newLength) {
        char[] copy = new char[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static char[] copyOfRange(char[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        char[] copy = new char[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(char[] a, char[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (a[i] != a2[i]) return false;
        return true;
    }
    public static int hashCode(char[] a) {
        if (a == null) return 0;
        int result = 1;
        for (char element : a) result = 31 * result + (element);
        return result;
    }
    public static String toString(char[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(char[] a, char val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(char[] a, int from, int to, char val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void sort(byte[] a) { sort(a, 0, a.length); }
    public static void sort(byte[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortByte(a, from, to - 1);
    }
    public static void parallelSort(byte[] a) { sort(a); }
    private static void qsortByte(byte[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            byte pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (a[i] < pv) i++;
                while (a[j] > pv) j--;
                if (i <= j) { byte t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortByte(a, lo, j); lo = i; } else { qsortByte(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            byte x = a[i];
            int j = i - 1;
            while (j >= lo && a[j] > x) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(byte[] a, byte key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(byte[] a, int from, int to, byte key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            byte midVal = a[mid];
            if (midVal < key) low = mid + 1; else if (midVal > key) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static byte[] copyOf(byte[] original, int newLength) {
        byte[] copy = new byte[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static byte[] copyOfRange(byte[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        byte[] copy = new byte[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(byte[] a, byte[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (a[i] != a2[i]) return false;
        return true;
    }
    public static int hashCode(byte[] a) {
        if (a == null) return 0;
        int result = 1;
        for (byte element : a) result = 31 * result + (element);
        return result;
    }
    public static String toString(byte[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(byte[] a, byte val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(byte[] a, int from, int to, byte val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void sort(double[] a) { sort(a, 0, a.length); }
    public static void sort(double[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortDouble(a, from, to - 1);
    }
    public static void parallelSort(double[] a) { sort(a); }
    private static void qsortDouble(double[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            double pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (Double.compare(a[i], pv) < 0) i++;
                while (Double.compare(a[j], pv) > 0) j--;
                if (i <= j) { double t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortDouble(a, lo, j); lo = i; } else { qsortDouble(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            double x = a[i];
            int j = i - 1;
            while (j >= lo && Double.compare(a[j], x) > 0) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(double[] a, double key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(double[] a, int from, int to, double key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            double midVal = a[mid];
            if (Double.compare(midVal, key) < 0) low = mid + 1; else if (Double.compare(midVal, key) > 0) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static double[] copyOf(double[] original, int newLength) {
        double[] copy = new double[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static double[] copyOfRange(double[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        double[] copy = new double[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(double[] a, double[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (Double.doubleToLongBits(a[i]) != Double.doubleToLongBits(a2[i])) return false;
        return true;
    }
    public static int hashCode(double[] a) {
        if (a == null) return 0;
        int result = 1;
        for (double element : a) result = 31 * result + (Double.hashCode(element));
        return result;
    }
    public static String toString(double[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(double[] a, double val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(double[] a, int from, int to, double val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void sort(float[] a) { sort(a, 0, a.length); }
    public static void sort(float[] a, int from, int to) {
        rangeCheck(a.length, from, to);
        qsortFloat(a, from, to - 1);
    }
    public static void parallelSort(float[] a) { sort(a); }
    private static void qsortFloat(float[] a, int lo, int hi) {
        while (hi - lo > 16) {
            int mid = (lo + hi) >>> 1;
            float pv = a[mid];
            int i = lo, j = hi;
            while (i <= j) {
                while (Float.compare(a[i], pv) < 0) i++;
                while (Float.compare(a[j], pv) > 0) j--;
                if (i <= j) { float t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
            }
            if (j - lo < hi - i) { qsortFloat(a, lo, j); lo = i; } else { qsortFloat(a, i, hi); hi = j; }
        }
        for (int i = lo + 1; i <= hi; i++) {
            float x = a[i];
            int j = i - 1;
            while (j >= lo && Float.compare(a[j], x) > 0) { a[j + 1] = a[j]; j--; }
            a[j + 1] = x;
        }
    }
    public static int binarySearch(float[] a, float key) { return binarySearch(a, 0, a.length, key); }
    public static int binarySearch(float[] a, int from, int to, float key) {
        int low = from, high = to - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            float midVal = a[mid];
            if (Float.compare(midVal, key) < 0) low = mid + 1; else if (Float.compare(midVal, key) > 0) high = mid - 1; else return mid;
        }
        return -(low + 1);
    }
    public static float[] copyOf(float[] original, int newLength) {
        float[] copy = new float[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static float[] copyOfRange(float[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        float[] copy = new float[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(float[] a, float[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (Float.floatToIntBits(a[i]) != Float.floatToIntBits(a2[i])) return false;
        return true;
    }
    public static int hashCode(float[] a) {
        if (a == null) return 0;
        int result = 1;
        for (float element : a) result = 31 * result + (Float.hashCode(element));
        return result;
    }
    public static String toString(float[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(float[] a, float val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(float[] a, int from, int to, float val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static boolean[] copyOf(boolean[] original, int newLength) {
        boolean[] copy = new boolean[newLength];
        System.arraycopy(original, 0, copy, 0, Math.min(original.length, newLength));
        return copy;
    }
    public static boolean[] copyOfRange(boolean[] original, int from, int to) {
        int newLength = to - from;
        if (newLength < 0) throw new IllegalArgumentException(from + " > " + to);
        boolean[] copy = new boolean[newLength];
        System.arraycopy(original, from, copy, 0, Math.min(original.length - from, newLength));
        return copy;
    }
    public static boolean equals(boolean[] a, boolean[] a2) {
        if (a == a2) return true;
        if (a == null || a2 == null) return false;
        int length = a.length;
        if (a2.length != length) return false;
        for (int i = 0; i < length; i++) if (a[i] != a2[i]) return false;
        return true;
    }
    public static int hashCode(boolean[] a) {
        if (a == null) return 0;
        int result = 1;
        for (boolean element : a) result = 31 * result + ((element ? 1231 : 1237));
        return result;
    }
    public static String toString(boolean[] a) {
        if (a == null) return "null";
        int iMax = a.length - 1;
        if (iMax == -1) return "[]";
        StringBuilder b = new StringBuilder();
        b.append('[');
        for (int i = 0; ; i++) {
            b.append(a[i]);
            if (i == iMax) return b.append(']').toString();
            b.append(", ");
        }
    }
    public static void fill(boolean[] a, boolean val) { for (int i = 0, len = a.length; i < len; i++) a[i] = val; }
    public static void fill(boolean[] a, int from, int to, boolean val) { rangeCheck(a.length, from, to); for (int i = from; i < to; i++) a[i] = val; }
    public static void setAll(int[] array, IntUnaryOperator generator) { for (int i = 0; i < array.length; i++) array[i] = generator.applyAsInt(i); }
    public static void setAll(long[] array, IntToLongFunction generator) { for (int i = 0; i < array.length; i++) array[i] = generator.applyAsLong(i); }
    public static void setAll(double[] array, IntToDoubleFunction generator) { for (int i = 0; i < array.length; i++) array[i] = generator.applyAsDouble(i); }
    public static IntStream stream(int[] array) { return IntStream.of(array); }
    public static IntStream stream(int[] array, int from, int to) { return IntStream.of(copyOfRange(array, from, to)); }
    public static LongStream stream(long[] array) { return LongStream.of(array); }
    public static DoubleStream stream(double[] array) { return DoubleStream.of(array); }
}
