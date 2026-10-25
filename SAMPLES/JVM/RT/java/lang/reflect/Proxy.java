package java.lang.reflect;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
public class Proxy implements java.io.Serializable {
    private static final long serialVersionUID = -2222568056686623797L;
    protected InvocationHandler h;
    private static final HashMap<List<Class<?>>, Class<?>> cache = new HashMap<>();
    private static final ArrayList<Class<?>> classes = new ArrayList<>();
    private static int counter;
    protected Proxy(InvocationHandler h) {
        if (h == null) throw new NullPointerException();
        this.h = h;
    }
    public static Class<?> getProxyClass(ClassLoader loader, Class<?>... interfaces) throws IllegalArgumentException {
        List<Class<?>> key = Arrays.asList(interfaces.clone());
        synchronized (cache) {
            Class<?> c = cache.get(key);
            if (c != null) return c;
            for (Class<?> i : interfaces) if (!i.isInterface()) throw new IllegalArgumentException(i.getName() + " is not an interface");
            boolean allPublic = true;
            String pkg = null;
            for (Class<?> i : interfaces) {
                if ((i.getModifiers() & Modifier.PUBLIC) == 0) {
                    allPublic = false;
                    pkg = i.getPackageName();
                }
            }
            String name = (allPublic ? "jdk.proxy1." : (pkg.isEmpty() ? "" : pkg + ".")) + "$Proxy" + (counter++);
            c = VM.defineProxy(interfaces.clone(), name);
            cache.put(key, c);
            classes.add(c);
            return c;
        }
    }
    public static Object newProxyInstance(ClassLoader loader, Class<?>[] interfaces, InvocationHandler h) {
        if (h == null) throw new NullPointerException();
        Class<?> c = getProxyClass(loader, interfaces);
        Object o = VM.allocate(c);
        ((Proxy) o).h = h;
        return o;
    }
    public static boolean isProxyClass(Class<?> cl) {
        synchronized (cache) { return classes.contains(cl); }
    }
    public static InvocationHandler getInvocationHandler(Object proxy) throws IllegalArgumentException {
        if (!(proxy instanceof Proxy) || !isProxyClass(proxy.getClass())) throw new IllegalArgumentException("not a proxy instance");
        return ((Proxy) proxy).h;
    }
    static Object dispatch(Object proxy, Class<?> decl, int mi, Object[] args) throws Throwable {
        Method m = Method.make(decl, mi);
        Proxy p = (Proxy) proxy;
        Object[] a = (args != null && args.length == 0) ? null : args;
        try {
            return p.h.invoke(proxy, m, a);
        } catch (RuntimeException | Error e) {
            throw e;
        } catch (Throwable t) {
            Class<?>[] ex = m.getExceptionTypes();
            for (Class<?> c : ex) if (c.isInstance(t)) throw t;
            throw new UndeclaredThrowableException(t);
        }
    }
}
