package java.util.jar;
import java.util.zip.ZipEntry;
public class JarEntry extends ZipEntry {
    Attributes attr;
    public JarEntry(String name) { super(name); }
    public JarEntry(ZipEntry ze) { super(ze); }
    public JarEntry(JarEntry je) { this((ZipEntry) je); attr = je.attr; }
    public Attributes getAttributes() throws java.io.IOException { return attr; }
    public java.security.CodeSigner[] getCodeSigners() { return null; }
}
