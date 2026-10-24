package java.util.concurrent;
public class ThreadLocalRandom extends java.util.Random {
    private static final long serialVersionUID = -5851777807851030925L;
    private static final ThreadLocalRandom inst = new ThreadLocalRandom();
    private ThreadLocalRandom() { super(); }
    public static ThreadLocalRandom current() { return inst; }
}
