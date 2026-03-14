# hello.awk - BEGIN, print, variables, chaines
# Compile avec : AWK86.EXE hello.awk hello.asm

BEGIN {
    msg = "Hello, World!"
    print msg
    x = 42
    print x
    print "La reponse est " x
}
