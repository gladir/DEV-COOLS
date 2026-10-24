package java.util.jar;
import java.io.*;
import java.util.*;
import java.util.zip.*;
import java.util.stream.Stream;
public class JarFile extends ZipFile {
    public static final String MANIFEST_NAME = "META-INF/MANIFEST.MF";
    private Manifest man;
    private boolean manRead;
    public JarFile(String name) throws IOException { super(name); }
    public JarFile(String name, boolean verify) throws IOException { super(name); }
    public JarFile(File file) throws IOException { super(file); }
    public JarFile(File file, boolean verify) throws IOException { super(file); }
    public JarFile(File file, boolean verify, int mode) throws IOException { super(file, mode); }
    public Manifest getManifest() throws IOException {
        if (!manRead) {
            manRead = true;
            ZipEntry e = super.getEntry(MANIFEST_NAME);
            if (e != null) man = new Manifest(super.getInputStream(e));
        }
        return man;
    }
    public JarEntry getJarEntry(String name) { return (JarEntry) getEntry(name); }
    public ZipEntry getEntry(String name) {
        ZipEntry ze = super.getEntry(name);
        if (ze != null) return new JarEntry(ze);
        return null;
    }
    public Enumeration<JarEntry> entries() {
        final Enumeration<? extends ZipEntry> e = super.entries();
        return new Enumeration<JarEntry>() {
            public boolean hasMoreElements() { return e.hasMoreElements(); }
            public JarEntry nextElement() { return new JarEntry(e.nextElement()); }
        };
    }
    public Stream<JarEntry> stream() { List<JarEntry> l = new ArrayList<>(); for (Enumeration<JarEntry> e = entries(); e.hasMoreElements();) l.add(e.nextElement()); return l.stream(); }
    public InputStream getInputStream(ZipEntry ze) throws IOException { return super.getInputStream(ze); }
}
