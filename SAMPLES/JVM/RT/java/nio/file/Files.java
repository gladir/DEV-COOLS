package java.nio.file;
import java.io.*;
import java.util.*;
import java.nio.charset.Charset;
public final class Files {
    private Files() {}
    public static boolean exists(Path p, Object... o) { return p.toFile().exists(); }
    public static boolean notExists(Path p, Object... o) { return !p.toFile().exists(); }
    public static boolean isDirectory(Path p, Object... o) { return p.toFile().isDirectory(); }
    public static boolean isRegularFile(Path p, Object... o) { return p.toFile().isFile(); }
    public static long size(Path p) throws IOException { return p.toFile().length(); }
    public static byte[] readAllBytes(Path p) throws IOException {
        File f = p.toFile();
        if (!f.exists()) throw new NoSuchFileException(p.toString());
        try (FileInputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            byte[] buf = new byte[4096];
            int n;
            while ((n = in.read(buf, 0, buf.length)) > 0) bo.write(buf, 0, n);
            return bo.toByteArray();
        }
    }
    public static String readString(Path p) throws IOException { return new String(readAllBytes(p)); }
    public static String readString(Path p, Charset cs) throws IOException { return new String(readAllBytes(p), cs); }
    public static List<String> readAllLines(Path p) throws IOException {
        String s = readString(p);
        List<String> l = new ArrayList<>();
        if (s.isEmpty()) return l;
        int i = 0, n = s.length();
        while (i < n) {
            int j = i;
            while (j < n && s.charAt(j) != '\n' && s.charAt(j) != '\r') j++;
            l.add(s.substring(i, j));
            if (j < n && s.charAt(j) == '\r' && j + 1 < n && s.charAt(j + 1) == '\n') j++;
            i = j + 1;
        }
        return l;
    }
    public static List<String> readAllLines(Path p, Charset cs) throws IOException { return readAllLines(p); }
    public static java.util.stream.Stream<String> lines(Path p) throws IOException { return readAllLines(p).stream(); }
    public static Path write(Path p, byte[] data, OpenOption... o) throws IOException {
        boolean append = false;
        for (OpenOption x : o) if (x == StandardOpenOption.APPEND) append = true;
        try (FileOutputStream out = new FileOutputStream(p.toFile(), append)) { out.write(data, 0, data.length); }
        return p;
    }
    public static Path write(Path p, Iterable<? extends CharSequence> lines, OpenOption... o) throws IOException {
        StringBuilder sb = new StringBuilder();
        for (CharSequence c : lines) sb.append(c).append('\n');
        return write(p, sb.toString().getBytes(), o);
    }
    public static Path write(Path p, Iterable<? extends CharSequence> lines, Charset cs, OpenOption... o) throws IOException { return write(p, lines, o); }
    public static Path writeString(Path p, CharSequence s, OpenOption... o) throws IOException { return write(p, s.toString().getBytes(), o); }
    public static Path writeString(Path p, CharSequence s, Charset cs, OpenOption... o) throws IOException { return write(p, s.toString().getBytes(), o); }
    public static void delete(Path p) throws IOException { if (!p.toFile().delete()) throw new NoSuchFileException(p.toString()); }
    public static boolean deleteIfExists(Path p) throws IOException { return p.toFile().delete(); }
    public static Path createDirectory(Path p) throws IOException { p.toFile().mkdir(); return p; }
    public static Path createDirectories(Path p) throws IOException { p.toFile().mkdirs(); return p; }
    public static Path createFile(Path p) throws IOException { p.toFile().createNewFile(); return p; }
    public static Path createTempFile(String prefix, String suffix, java.nio.file.attribute.FileAttribute<?>... attrs) throws IOException { return File.createTempFile(prefix, suffix).toPath(); }
    public static Path copy(Path a, Path b, Object... o) throws IOException { write(b, readAllBytes(a)); return b; }
    public static Path move(Path a, Path b, Object... o) throws IOException { a.toFile().renameTo(b.toFile()); return b; }
    public static java.util.stream.Stream<Path> list(Path d) throws IOException {
        String[] n = d.toFile().list();
        List<Path> l = new ArrayList<>();
        if (n != null) { Arrays.sort(n); for (String s : n) l.add(d.resolve(s)); }
        return l.stream();
    }
    public static BufferedReader newBufferedReader(Path p) throws IOException { return new BufferedReader(new FileReader(p.toFile())); }
    public static BufferedWriter newBufferedWriter(Path p, OpenOption... o) throws IOException { return new BufferedWriter(new FileWriter(p.toFile())); }
}
