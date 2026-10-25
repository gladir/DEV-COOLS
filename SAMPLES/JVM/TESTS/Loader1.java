import java.io.*;
import java.net.*;
import java.nio.file.*;
public class Loader1 {
    static class Mem extends ClassLoader {
        final byte[] b; Mem(ClassLoader p, byte[] b) { super(p); this.b = b; }
        protected Class<?> findClass(String n) throws ClassNotFoundException { if (n.equals("Plugin")) return defineClass(n, b, 0, b.length); throw new ClassNotFoundException(n); }
    }
    public static void main(String[] a) throws Exception {
        byte[] bytes = Files.readAllBytes(Paths.get("ext/Plugin.class"));
        Class<?> c = new Mem(Loader1.class.getClassLoader(), bytes).loadClass("Plugin");
        Runnable r = (Runnable) c.getDeclaredConstructor().newInstance();
        r.run(); System.out.println(r + " " + c.getName());
        URLClassLoader u = new URLClassLoader(new URL[]{new File("ext/").toURI().toURL()});
        Class<?> c2 = Class.forName("Plugin", true, u);
        System.out.println(c2.getMethod("toString").invoke(c2.getDeclaredConstructor().newInstance()));
        System.out.println(ClassLoader.getSystemClassLoader().getName() + " " + (String.class.getClassLoader() == null) + " " + (Loader1.class.getClassLoader() != null) + " " + Thread.currentThread().getContextClassLoader().getClass().getSimpleName().length());
        try { Class.forName("Nope", true, u); } catch (ClassNotFoundException e) { System.out.println("CNF " + e.getMessage()); }
        URI uri = new URI("http://user@host.com:8080/a/b/../c%20d?x=1&y=2#frag");
        System.out.println(uri.getScheme() + " " + uri.getUserInfo() + " " + uri.getHost() + " " + uri.getPort() + " " + uri.getPath() + " " + uri.getQuery() + " " + uri.getFragment() + " " + uri.normalize() + " " + uri.resolve("../z"));
        URL url = new URL("https://example.com:443/p/q.html?k=v#r"); System.out.println(url.getHost() + url.getPort() + url.getPath() + url.getQuery() + url.getRef() + url.getProtocol() + url.getFile());
        System.out.println(URLEncoder.encode("a b&c=é/ü", "UTF-8") + " " + URLDecoder.decode("a+b%26c%3D%C3%A9", "UTF-8"));
        System.out.println(new File("/tmp/x y.txt").toURI());
    }
}
