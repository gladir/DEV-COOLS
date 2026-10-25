package java.util.jar;
import java.io.*;
import java.util.zip.*;
public class JarInputStream extends ZipInputStream {
    private Manifest man;
    private JarEntry first;
    public JarInputStream(InputStream in) throws IOException { this(in, true); }
    public JarInputStream(InputStream in, boolean verify) throws IOException {
        super(in);
        JarEntry e = (JarEntry) super.getNextEntry();
        if (e != null && e.getName().equalsIgnoreCase("META-INF/")) e = (JarEntry) super.getNextEntry();
        first = e;
        if (e != null && e.getName().equalsIgnoreCase(JarFile.MANIFEST_NAME)) {
            man = new Manifest(this);
            first = null;
        }
    }
    public Manifest getManifest() { return man; }
    public ZipEntry getNextEntry() throws IOException {
        JarEntry e;
        if (first == null) e = (JarEntry) super.getNextEntry();
        else { e = first; first = null; }
        return e;
    }
    public JarEntry getNextJarEntry() throws IOException { return (JarEntry) getNextEntry(); }
    protected ZipEntry createZipEntry(String name) { return new JarEntry(name); }
}
