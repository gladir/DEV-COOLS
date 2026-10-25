package java.io;
public class FileWriter extends OutputStreamWriter {
    public FileWriter(String name) throws IOException { super(new FileOutputStream(name)); }
    public FileWriter(String name, boolean append) throws IOException { super(new FileOutputStream(name, append)); }
    public FileWriter(File f) throws IOException { super(new FileOutputStream(f)); }
    public FileWriter(File f, boolean append) throws IOException { super(new FileOutputStream(f, append)); }
}
