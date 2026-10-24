package java.util.jar;
import java.io.*;
import java.util.zip.*;
public class JarOutputStream extends ZipOutputStream {
    public JarOutputStream(OutputStream out, Manifest man) throws IOException {
        super(out);
        if (man == null) throw new NullPointerException("man");
        ZipEntry e = new ZipEntry(JarFile.MANIFEST_NAME);
        putNextEntry(e);
        man.write(this);
        closeEntry();
    }
    public JarOutputStream(OutputStream out) throws IOException { super(out); }
    public void putNextEntry(ZipEntry ze) throws IOException { super.putNextEntry(ze); }
}
