import java.io.*;
import java.math.*;
import java.text.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.regex.*;
public class Serial7 {
    @SuppressWarnings("unchecked")
    static <T> T rt(T o) throws Exception {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ObjectOutputStream oo = new ObjectOutputStream(bo)) { oo.writeObject(o); }
        try (ObjectInputStream oi = new ObjectInputStream(new ByteArrayInputStream(bo.toByteArray()))) { return (T) oi.readObject(); }
    }
    static void p(String n, Object o) throws Exception {
        try { Object r = rt(o); System.out.println(n + " -> " + r + (r != null ? " " + r.getClass().getSimpleName() : "")); }
        catch (Throwable t) { System.out.println(n + " FAIL " + t); }
    }
    public static void main(String[] a) throws Exception {
        ConcurrentHashMap<String, Integer> chm = new ConcurrentHashMap<>(); chm.put("a", 1); chm.put("b", 2);
        p("CHM", chm);
        p("COWAL", new CopyOnWriteArrayList<>(List.of(1, 2, 3)));
        p("COWAS", new CopyOnWriteArraySet<>(List.of(1, 2, 3)));
        LinkedBlockingQueue<Integer> lbq = new LinkedBlockingQueue<>(); lbq.add(5); lbq.add(6); p("LBQ", lbq);
        p("ABQ", new ArrayBlockingQueue<Integer>(5));
        p("PBQ", new PriorityBlockingQueue<>(List.of(3, 1, 2)));
        p("CLQ", new ConcurrentLinkedQueue<>(List.of(1, 2)));
        p("AtomicLong", new AtomicLong(7)); p("AtomicBoolean", new AtomicBoolean(true)); p("AtomicRef", new AtomicReference<>("r")); p("AIA", new AtomicIntegerArray(new int[]{1, 2}));
        p("DecimalFormat", new DecimalFormat("#,##0.00").format(1234.5));
        DecimalFormat df = new DecimalFormat("#,##0.00");
        DecimalFormat df2 = rt(df); System.out.println(df2.format(98765.4321));
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd"); SimpleDateFormat sdf2 = rt(sdf); System.out.println(sdf2.format(new Date(0)));
        Calendar cal = new GregorianCalendar(2024, 1, 29); Calendar cal2 = rt(cal); System.out.println(cal2.get(Calendar.YEAR) + "-" + cal2.get(Calendar.MONTH) + "-" + cal2.get(Calendar.DAY_OF_MONTH));
        Pattern pt = Pattern.compile("(a+)b", Pattern.CASE_INSENSITIVE); Pattern pt2 = rt(pt); System.out.println(pt2 + " " + pt2.matcher("xAAb").find() + " " + pt2.flags());
        p("MathContext", MathContext.DECIMAL64); p("Locale", Locale.FRANCE); p("TimeZone", TimeZone.getTimeZone("UTC"));
        p("RoundingMode", RoundingMode.HALF_UP); p("Opt-less Date", new Date(5));
        p("Exception", new IllegalStateException("boom", new RuntimeException("inner")));
        Exception e = rt(new IllegalStateException("boom", new RuntimeException("inner")));
        System.out.println(e.getMessage() + " " + e.getCause().getMessage() + " " + e.getStackTrace().length + " " + e.getStackTrace()[0].getMethodName());
        Exception e2 = new Exception("sup"); e2.addSuppressed(new Error("e")); Exception e3 = rt(e2); System.out.println(e3.getSuppressed().length + " " + e3.getSuppressed()[0]);
        e3.printStackTrace(System.out);
        p("file", new File("/tmp/x/y.txt"));
        p("BigDecimal", new BigDecimal("-0.000123456789e5"));
        p("TreeMap-cmp", new TreeMap<>(Comparator.reverseOrder()) {{ put(1, "a"); put(2, "b"); }});
        p("unmod", Collections.unmodifiableMap(new TreeMap<>(Map.of(1, 2))));
        p("sync", Collections.synchronizedList(new ArrayList<>(List.of(1))));
        p("singleton", Collections.singletonList(1)); p("nCopies", Collections.nCopies(3, "x")); p("emptyMap", Collections.emptyMap());
        p("EnumSet", EnumSet.of(Thread.State.NEW, Thread.State.BLOCKED)); p("IdentityHash-less", new StringBuffer("sbuf"));
        p("Optional?", Arrays.asList(1, null));
        Object[] shared = new Object[3]; shared[0] = shared; shared[1] = "s"; shared[2] = shared[1];
        Object[] sr = rt(shared); System.out.println((sr[0] == sr) + " " + (sr[1] == sr[2]));
        System.out.println(rt(new int[][]{{1, 2}, {3}}).length + " " + rt(Integer.valueOf(127)) + " " + rt("é€𝄞".toString()));
    }
}
