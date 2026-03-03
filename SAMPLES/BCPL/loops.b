// loops.b - Demonstration des boucles BCPL
// Compile avec : BCPL86 loops.b
// Illustre : FOR, WHILE, UNTIL, REPEAT, BREAK

LET printline() BE $(
    WRITES("------------------------------*N")
$)

LET start() BE $(
    LET i = 0
    LET s = 0

    // ---- Boucle FOR simple ----
    printline()
    WRITES("FOR i = 1 TO 10*N")
    FOR i = 1 TO 10 DO $(
        WRITEN(i)
        WRITECH(32)        // espace (ASCII 32)
    $)
    NEWLINE()

    // ---- FOR avec BY -1 (decroissant) ----
    printline()
    WRITES("FOR i = 10 TO 1 BY -1*N")
    FOR i = 10 TO 1 BY -1 DO $(
        WRITEN(i)
        WRITECH(32)
    $)
    NEWLINE()

    // ---- FOR calculer somme cumulative ----
    printline()
    WRITES("Somme 1..100 avec FOR*N")
    s := 0
    FOR i = 1 TO 100 DO
        s := s + i
    WRITES("  1 + 2 + ... + 100 = ")
    WRITEN(s)
    NEWLINE()

    // ---- Boucle WHILE ----
    printline()
    WRITES("Puissances de 2 avec WHILE*N")
    i := 1
    WHILE i <= 1024 DO $(
        WRITEN(i)
        WRITECH(32)
        i := i * 2
    $)
    NEWLINE()

    // ---- Boucle UNTIL (s'arrete quand la condition devient vraie) ----
    printline()
    WRITES("Compte 0..9 avec UNTIL*N")
    i := 0
    UNTIL i = 10 DO $(
        WRITEN(i)
        WRITECH(32)
        i := i + 1
    $)
    NEWLINE()

    // ---- Boucle REPEAT REPEATWHILE ----
    printline()
    WRITES("Tableau * avec REPEAT*N")
    i := 1
    REPEAT $(
        WRITEN(i)
        WRITES(" * 7 = ")
        WRITEN(i * 7)
        NEWLINE()
        i := i + 1
    $) REPEATWHILE i <= 5

    // ---- FOR avec BREAK ----
    printline()
    WRITES("FOR avec BREAK a i=5*N")
    FOR i = 1 TO 100 DO $(
        IF i > 5 DO BREAK
        WRITEN(i)
        WRITECH(32)
    $)
    NEWLINE()

    printline()
    WRITES("Fin des boucles.*N")
$)
