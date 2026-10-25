import java.io.*;
import java.util.*;
import java.util.jar.*;
import java.util.zip.*;
public class Zip1 {
    static byte[] sample(int n) { byte[] b = new byte[n]; Random r = new Random(7); for (int i = 0; i < n; i++) b[i] = (byte) ("abcdefgh ".charAt(r.nextInt(9)) + (i % 97 == 0 ? r.nextInt(3) : 0)); return b; }
    public static void main(String[] a) throws Exception {
        try (ZipFile zf = new ZipFile("app.jar")) {
            List<String> names = new ArrayList<>();
            for (Enumeration<? extends ZipEntry> e = zf.entries(); e.hasMoreElements();) { ZipEntry ze = e.nextElement(); names.add(ze.getName() + ":" + ze.getSize() + ":" + Long.toHexString(ze.getCrc()) + ":" + ze.getMethod() + ":" + ze.isDirectory()); }
            System.out.println(names + " " + zf.size());
            ZipEntry d = zf.getEntry("res/data.txt");
            System.out.println(new String(zf.getInputStream(d).readAllBytes()).length() + " " + zf.getEntry("nope"));
        }
        try (JarFile jf = new JarFile("app.jar")) {
            Manifest m = jf.getManifest();
            System.out.println(m.getMainAttributes().getValue("Main-Class") + " " + m.getMainAttributes().getValue(Attributes.Name.MANIFEST_VERSION) + " " + jf.getJarEntry("Main.class").getSize());
        }
        try (ZipInputStream zi = new ZipInputStream(new FileInputStream("app.jar"))) {
            ZipEntry e; while ((e = zi.getNextEntry()) != null) { byte[] b = zi.readAllBytes(); CRC32 c = new CRC32(); c.update(b); System.out.print(e.getName() + "=" + b.length + "/" + Long.toHexString(c.getValue()) + " "); }
            System.out.println();
        }
        byte[] data = sample(50000);
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        try (ZipOutputStream zo = new ZipOutputStream(bo)) {
            zo.setComment("cmt");
            zo.putNextEntry(new ZipEntry("a/b.txt")); zo.write(data); zo.closeEntry();
            ZipEntry st = new ZipEntry("stored.bin"); st.setMethod(ZipEntry.STORED); st.setSize(3); st.setCompressedSize(3); CRC32 c = new CRC32(); c.update(new byte[]{1, 2, 3}); st.setCrc(c.getValue());
            zo.putNextEntry(st); zo.write(new byte[]{1, 2, 3}); zo.closeEntry();
            zo.putNextEntry(new ZipEntry("dir/")); zo.closeEntry();
            zo.putNextEntry(new ZipEntry("é.txt")); zo.write("accent".getBytes()); zo.closeEntry();
        }
        try (FileOutputStream fo = new FileOutputStream("out.zip")) { fo.write(bo.toByteArray()); }
        try (ZipInputStream zi = new ZipInputStream(new ByteArrayInputStream(bo.toByteArray()))) {
            ZipEntry e; while ((e = zi.getNextEntry()) != null) { byte[] b = zi.readAllBytes(); System.out.print(e.getName() + "=" + b.length + (b.length == 50000 ? Arrays.equals(b, data) : "") + " "); }
            System.out.println();
        }
        try (ZipFile zf = new ZipFile("out.zip")) { System.out.println(zf.size() + " " + zf.getComment() + " " + Arrays.equals(zf.getInputStream(zf.getEntry("a/b.txt")).readAllBytes(), data)); }
        // gzip
        ByteArrayOutputStream gz = new ByteArrayOutputStream();
        try (GZIPOutputStream go = new GZIPOutputStream(gz)) { go.write(data); go.write("tail".getBytes()); }
        try (FileOutputStream fo = new FileOutputStream("mine.gz")) { fo.write(gz.toByteArray()); }
        try (GZIPInputStream gi = new GZIPInputStream(new ByteArrayInputStream(gz.toByteArray()))) { byte[] r = gi.readAllBytes(); System.out.println(r.length + " " + Arrays.equals(Arrays.copyOf(r, 50000), data)); }
        try (GZIPInputStream gi = new GZIPInputStream(new FileInputStream("real.gz"))) { System.out.println(new String(gi.readAllBytes()).length()); }
        // Deflater / Inflater
        Deflater df = new Deflater(); df.setInput(data); df.finish(); byte[] buf = new byte[100000]; int n = df.deflate(buf); df.end();
        Inflater inf = new Inflater(); inf.setInput(buf, 0, n); byte[] out = new byte[60000]; int m = inf.inflate(out); System.out.println(m + " " + inf.finished() + " " + Arrays.equals(Arrays.copyOf(out, m), data) + " " + (n < 20000));
        Adler32 ad = new Adler32(); ad.update(data); CRC32 cr = new CRC32(); cr.update(data); System.out.println(ad.getValue() + " " + cr.getValue());
        try { new GZIPInputStream(new ByteArrayInputStream(new byte[]{1, 2, 3, 4})); } catch (Exception e) { System.out.println(e); }
        try { Inflater i2 = new Inflater(); i2.setInput(new byte[]{1, 2, 3, 4, 5}); i2.inflate(new byte[10]); } catch (Exception e) { System.out.println(e); }
        // Manifest write
        Manifest mf = new Manifest(); mf.getMainAttributes().put(Attributes.Name.MANIFEST_VERSION, "1.0"); mf.getMainAttributes().putValue("Main-Class", "x.Y"); mf.getMainAttributes().putValue("Long-Key", "v".repeat(100));
        ByteArrayOutputStream mo = new ByteArrayOutputStream(); mf.write(mo); System.out.println(mo.toString().replace("\r\n", "|"));
        Manifest m2 = new Manifest(new ByteArrayInputStream(mo.toByteArray())); System.out.println(m2.getMainAttributes().getValue("Long-Key").length() + " " + m2.getMainAttributes().size());
        ByteArrayOutputStream jb = new ByteArrayOutputStream(); try (JarOutputStream jo = new JarOutputStream(jb, mf)) { jo.putNextEntry(new JarEntry("k.txt")); jo.write(5); jo.closeEntry(); }
        try (JarInputStream ji = new JarInputStream(new ByteArrayInputStream(jb.toByteArray()))) { System.out.println(ji.getManifest().getMainAttributes().getValue("Main-Class") + " " + ji.getNextJarEntry().getName()); }
    }
}
