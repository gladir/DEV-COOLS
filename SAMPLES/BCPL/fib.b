// fib.b - Fibonacci en BCPL : expression conditionnelle ->
// Compile avec : BCPL86 fib.b
// Illustre : LET f(n) = expr -> val1, val2  (forme expression)
//            recursivite, FOR, WRITES, WRITEN

// Fibonacci recursif : fib(0)=0, fib(1)=1, fib(n)=fib(n-1)+fib(n-2)
// BCPL : -> est l'expression conditionnelle (cond -> vrai, faux)
// Le compilateur sauvegarde AX (PUSH) avant d'evaluer le membre droit,
// donc fib(n-1) + fib(n-2) fonctionne correctement.
LET fib(n) = n <= 1 -> n, fib(n-1) + fib(n-2)

// Fibonacci iteratif (VALOF + WHILE + RESULTIS)
LET fibit(n) = VALOF $(
    LET a = 0
    LET b = 1
    LET t = 0
    LET i = 0
    UNLESS n > 0 DO RESULTIS 0
    FOR i = 1 TO n-1 DO $(
        t := a + b
        a := b
        b := t
    $)
    RESULTIS b
$)

// Affiche un separateur
LET sep() BE $(
    WRITES("---------------------------*N")
$)

LET start() BE $(
    LET i = 0

    sep()
    WRITES("  FIBONACCI RECURSIF*N")
    sep()
    FOR i = 0 TO 12 DO $(
        WRITES("  fib(")
        WRITEN(i)
        WRITES(") = ")
        WRITEN(fib(i))
        NEWLINE()
    $)

    sep()
    WRITES("  FIBONACCI ITERATIF*N")
    sep()
    FOR i = 0 TO 12 DO $(
        WRITES("  fibit(")
        WRITEN(i)
        WRITES(") = ")
        WRITEN(fibit(i))
        NEWLINE()
    $)

    sep()
    WRITES("  Suite de Fibonacci jusqu'a 1000 :**N")
    sep()
    LET a = 0
    LET b = 1
    LET t = 0
    WHILE a <= 1000 DO $(
        WRITEN(a)
        NEWLINE()
        t := a + b
        a := b
        b := t
    $)

    FINISH
$)
