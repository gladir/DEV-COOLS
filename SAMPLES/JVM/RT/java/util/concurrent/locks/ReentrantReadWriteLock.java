package java.util.concurrent.locks;
public class ReentrantReadWriteLock implements ReadWriteLock {
    private static final long serialVersionUID = -6992448646407690164L;
    private final ReentrantLock l = new ReentrantLock();
    public ReentrantReadWriteLock() { }
    public ReentrantReadWriteLock(boolean fair) { }
    public Lock readLock() { return l; }
    public Lock writeLock() { return l; }
}
