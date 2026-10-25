import java.util.*;
import java.io.*;
public class Test04_Exceptions {
    static class MyEx extends Exception {
        int code;
        MyEx(String m, int code) { super(m); this.code = code; }
    }
    static class Res implements AutoCloseable {
        String n;
        Res(String n) { this.n = n; System.out.println("open " + n); }
        public void close() { System.out.println("close " + n); }
    }
    static int depth;
    static { depth = 3; System.out.println("static init"); }
    int inst; { inst = 9; }
    static void thrower(int x) throws MyEx { if (x > 1) throw new MyEx("big", x); }
    static synchronized void sync() { System.out.println("sync"); }
    public static void main(String[] args) throws Exception {
        try (Res a = new Res("a"); Res b = new Res("b")) {
            System.out.println("body");
            thrower(5);
        } catch (MyEx e) {
            System.out.println("caught " + e.getMessage() + e.code);
        } finally {
            System.out.println("fin");
        }
        Object lock = new Object();
        synchronized (lock) { System.out.println("locked"); }
        sync();
        try { Object o = "s"; Integer i = (Integer) o; }
        catch (ClassCastException | IllegalStateException e) { System.out.println("cce"); }
        System.out.println(new Test04_Exceptions().inst + depth);
        long l = Long.MAX_VALUE; double d = 1e300 * 1e10;
        System.out.println(l + " " + d + " " + (0.0 / 0.0) + " " + (float) 1 / 3);
        System.out.println(Math.max(3, 4L) + Math.abs(-2.5) + " " + Integer.parseInt("42") + " " + Integer.toBinaryString(10));
        String s = "Hello, World";
        System.out.println(s.substring(7).toLowerCase() + s.indexOf('W') + s.charAt(1) + s.length() + s.replace('l', 'L'));
        System.out.println(String.format("%5d|%-5s|%08.3f", 42, "ab", 3.14159));
        StringBuilder sb = new StringBuilder("abc");
        sb.insert(0, 12).reverse().append(3.5).append('x').append(true);
        System.out.println(sb.toString());
        int i = 0;
        i = i++ + ++i;
        System.out.println(i);
        int[] a = {1, 2, 3};
        int idx = 0;
        a[idx++] += 10;
        a[idx] <<= 2;
        System.out.println(Arrays.toString(a) + idx);
        char c = 'x'; c++; c += 2;
        short sh = (short) 40000; byte by = (byte) 200;
        System.out.println(c + " " + sh + " " + by + " " + (sh & 0xFFFF) + " " + (by >>> 2) + " " + (-17 >> 2) + " " + (-17 >>> 28));
        boolean flag = true;
        flag &= false; flag |= true; flag ^= true;
        System.out.println(flag);
        double dd = 5; dd /= 2; dd -= 0.25;
        System.out.println(dd);
        long ll = 5; ll *= 3.7;
        System.out.println(ll);
        System.out.println(010 + 0x1F + 0b101 + 1_000);
        Object[] objs = {1, "two", 3.0, 'c', null, new int[0].length};
        for (Object x : objs) System.out.print((x == null ? "null" : x.getClass().getSimpleName()) + ";");
        System.out.println();
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        String line = br.readLine();
        System.out.println("read: " + line);
    }
}
