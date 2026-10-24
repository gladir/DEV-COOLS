package java.util.concurrent.locks;
public class ReentrantReadWriteLock implements ReadWriteLock {
    private final ReentrantLock l = new ReentrantLock();
    public ReentrantReadWriteLock() { }
    public ReentrantReadWriteLock(boolean fair) { }
    public Lock readLock() { return l; }
    public Lock writeLock() { return l; }
}
