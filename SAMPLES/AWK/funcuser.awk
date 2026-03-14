# funcuser.awk - Fonctions utilisateur, recursion, return
# Compile avec : AWK86.EXE funcuser.awk funcuser.asm

function max(a, b) {
    if (a > b)
        return a
    return b
}

function factorial(n) {
    if (n <= 1)
        return 1
    return n * factorial(n - 1)
}

function fibonacci(n) {
    if (n <= 1)
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)
}

BEGIN {
    print "max(3,7) = " max(3, 7)
    print "max(10,5) = " max(10, 5)

    print "5! = " factorial(5)
    print "7! = " factorial(7)

    print "fib(8) = " fibonacci(8)
    print "fib(10) = " fibonacci(10)
}
