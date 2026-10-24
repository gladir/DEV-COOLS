package java.lang;
public final class StackTraceElement implements java.io.Serializable {
    private static final long serialVersionUID = 6992337162326171013L;
    private String classLoaderName, moduleName, moduleVersion;
    private String declaringClass, methodName, fileName;
    private int lineNumber;
    private byte format = 0;
    public StackTraceElement(String declaringClass, String methodName, String fileName, int lineNumber) {
        this.declaringClass = declaringClass; this.methodName = methodName; this.fileName = fileName; this.lineNumber = lineNumber;
    }
    public String getClassName() { return declaringClass; }
    public String getMethodName() { return methodName; }
    public String getFileName() { return fileName; }
    public int getLineNumber() { return lineNumber; }
    public boolean isNativeMethod() { return lineNumber == -2; }
    public boolean equals(Object o) { return o instanceof StackTraceElement e && e.lineNumber == lineNumber && e.declaringClass.equals(declaringClass) && e.methodName.equals(methodName) && java.util.Objects.equals(e.fileName, fileName); }
    public int hashCode() { return 31 * (31 * declaringClass.hashCode() + methodName.hashCode()) + lineNumber; }
    public String toString() {
        return declaringClass + "." + methodName + "(" + (fileName == null ? "Unknown Source" : (lineNumber >= 0 ? fileName + ":" + lineNumber : fileName)) + ")";
    }
}
