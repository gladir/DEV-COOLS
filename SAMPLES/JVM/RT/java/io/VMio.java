package java.io;
class VMio {
    static void writeByte(int fd, int b) { java.lang.VM.writeByte(fd, b); }
}
