package java.net;
public class URLClassLoader extends ClassLoader implements java.io.Closeable {
    private final URL[] urls;
    public URLClassLoader(URL[] urls, ClassLoader parent) {
        super(parent);
        this.urls = urls.clone();
        for (URL u : urls) addUrl(u);
    }
    public URLClassLoader(URL[] urls) { this(urls, ClassLoader.getSystemClassLoader()); }
    private static void addUrl(URL u) {
        if (u.getProtocol().equals("file")) {
            try { java.lang.VM.addClasspath(URLDecoder.decode(u.getPath(), "UTF-8")); } catch (java.io.UnsupportedEncodingException e) { }
        }
    }
    public URL[] getURLs() { return urls.clone(); }
    public void close() throws java.io.IOException { }
    protected void addURL(URL url) { addUrl(url); }
}
