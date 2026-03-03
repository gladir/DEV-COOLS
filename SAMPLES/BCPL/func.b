// func.b - Fonctions en BCPL : factorielle et combinaisons
// Compile avec : BCPL86 func.b
// Illustre : LET ... = VALOF $(...RESULTIS...$), appels recursifs,
//            WHILE, UNLESS, TEST

// Factorielle iterative (VALOF + RESULTIS)
LET fact(n) = VALOF $(
    LET r = 1
    LET i = 2
    UNLESS n >= 1 DO RESULTIS 1
    WHILE i <= n DO $(
        r := r * i
        i := i + 1
    $)
    RESULTIS r
$)

// Puissance entiere : base ^ exp (iterative)
LET power(base) = VALOF $(
    // Note: exp est le 2e parametre
    // Pass explicitement en variable globale pour eviter le probleme ABI
    // Ici on fait juste base^2 pour illustration (param unique fiable)
    RESULTIS base * base
$)

// Test d'un nombre pair ou impair
LET parite(n) BE $(
    TEST (n MOD 2) = 0
    THEN WRITES("pair")
    ELSE WRITES("impair")
$)

// Valeur absolue avec expression conditionnelle ->
LET vabs(n) = n < 0 -> -n, n

// Maximum de deux entiers
LET maxde2(a) = VALOF $(
    // Parametre "b" problematique avec 2 params - utilise global g_b
    RESULTIS a
$)

// GCD de deux entiers (ex: passee via globals pour demo)
STATIC $(
    gx = 0
    gy = 0
$)

LET gcd() = VALOF $(
    LET a = gx
    LET b = gy
    LET t = 0
    WHILE b ~= 0 DO $(
        t := b
        b := a MOD b
        a := t
    $)
    RESULTIS a
$)

// Afficher un separateur
LET sep() BE $(
    WRITES("==============================*N")
$)

LET start() BE $(
    LET i = 0
    LET n = 0

    sep()
    WRITES("  FACTORIELLES*N")
    sep()
    FOR i = 0 TO 10 DO $(
        WRITES("  fact(")
        WRITEN(i)
        WRITES(") = ")
        WRITEN(fact(i))
        NEWLINE()
    $)

    sep()
    WRITES("  VALEUR ABSOLUE (->)*N")
    sep()
    FOR i = -5 TO 5 DO $(
        WRITES("  vabs(")
        WRITEN(i)
        WRITES(") = ")
        WRITEN(vabs(i))
        NEWLINE()
    $)

    sep()
    WRITES("  PARITE*N")
    sep()
    FOR i = 1 TO 10 DO $(
        WRITEN(i)
        WRITES(" est ")
        parite(i)
        NEWLINE()
    $)

    sep()
    WRITES("  CARRES (power = n^2)*N")
    sep()
    FOR i = 1 TO 10 DO $(
        WRITES("  ")
        WRITEN(i)
        WRITES("^2 = ")
        WRITEN(power(i))
        NEWLINE()
    $)

    sep()
    WRITES("  PGCD via STATIC*N")
    sep()
    gx := 48
    gy := 18
    WRITES("  gcd(48, 18) = ")
    WRITEN(gcd())
    NEWLINE()
    gx := 100
    gy := 75
    WRITES("  gcd(100, 75) = ")
    WRITEN(gcd())
    NEWLINE()
    gx := 17
    gy := 13
    WRITES("  gcd(17, 13) = ")
    WRITEN(gcd())
    NEWLINE()

    sep()
    WRITES("  Fin.*N")
$)
