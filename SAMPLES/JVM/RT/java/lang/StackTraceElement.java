package java.lang;
public final class StackTraceElement implements java.io.Serializable {
    private String declaringClass, methodName, fileName;
    private int lineNumber;
    public StackTraceElement(String declaringClass, String methodName, String fileName, int lineNumber) {
        this.declaringClass = declaringClass; this.methodName = methodName; this.fileName = fileName; this.lineNumber = lineNumber;
    }
    public String getClassName() { return declaringClass; }
    public String getMethodName() { return methodName; }
    public String getFileName() { return fileName; }
    public int getLineNumber() { return lineNumber; }
    public boolean isNativeMethod() { return lineNumber == -2; }
    public String toString() {
        return declaringClass + "." + methodName + "(" + (fileName == null ? "Unknown Source" : (lineNumber >= 0 ? fileName + ":" + lineNumber : fileName)) + ")";
    }
}
