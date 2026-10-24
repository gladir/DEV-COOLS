package java.io;
public class FileReader extends InputStreamReader {
    public FileReader(String name) throws FileNotFoundException { super(new FileInputStream(name)); }
    public FileReader(File f) throws FileNotFoundException { super(new FileInputStream(f)); }
    public FileReader(String name, java.nio.charset.Charset cs) throws IOException { super(new FileInputStream(name)); }
}
