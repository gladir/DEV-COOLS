// switchon.b - SWITCHON/CASE/DEFAULT en BCPL
// Compile avec : BCPL86 switchon.b
// Illustre : SWITCHON expr INTO $(...$), CASE n:, DEFAULT:, ENDCASE

// Retourne le nom du jour de la semaine (1=Lundi..7=Dimanche)
LET journom(n) BE $(
    SWITCHON n INTO $(
        CASE 1: WRITES("Lundi")     ENDCASE
        CASE 2: WRITES("Mardi")     ENDCASE
        CASE 3: WRITES("Mercredi")  ENDCASE
        CASE 4: WRITES("Jeudi")     ENDCASE
        CASE 5: WRITES("Vendredi")  ENDCASE
        CASE 6: WRITES("Samedi")    ENDCASE
        CASE 7: WRITES("Dimanche")  ENDCASE
        DEFAULT: WRITES("Inconnu")
    $)
$)

// Categorie d'un entier
LET categorie(n) BE $(
    SWITCHON n INTO $(
        CASE 0: WRITES("zero")      ENDCASE
        CASE 1:
        CASE 3:
        CASE 5:
        CASE 7:
        CASE 9: WRITES("impair")    ENDCASE
        CASE 2:
        CASE 4:
        CASE 6:
        CASE 8: WRITES("pair")      ENDCASE
        DEFAULT: WRITES("grand")
    $)
$)

// Note scolaire : A B C D F
LET notename(n) BE $(
    SWITCHON n INTO $(
        CASE 90: WRITES("A+")  ENDCASE
        CASE 80: WRITES("A")   ENDCASE
        CASE 70: WRITES("B")   ENDCASE
        CASE 60: WRITES("C")   ENDCASE
        CASE 50: WRITES("D")   ENDCASE
        DEFAULT: WRITES("F")
    $)
$)

// Calculatrice simple via SWITCHON
LET calc_op(a) BE $(
    // Simule operation + avec b passe via STATIC
    WRITES("op applique a ")
    WRITEN(a)
    NEWLINE()
$)

LET sep() BE $(
    WRITES("============================*N")
$)

LET start() BE $(
    LET i = 0

    sep()
    WRITES("  JOURS DE LA SEMAINE*N")
    sep()
    FOR i = 1 TO 7 DO $(
        WRITEN(i)
        WRITES(" -> ")
        journom(i)
        NEWLINE()
    $)
    WRITES("8 -> ")
    journom(8)
    NEWLINE()

    sep()
    WRITES("  CATEGORIES 0..10*N")
    sep()
    FOR i = 0 TO 10 DO $(
        WRITEN(i)
        WRITES(" : ")
        categorie(i)
        NEWLINE()
    $)

    sep()
    WRITES("  NOTES SCOLAIRES*N")
    sep()
    WRITES("90 -> ")  notename(90)  NEWLINE()
    WRITES("80 -> ")  notename(80)  NEWLINE()
    WRITES("70 -> ")  notename(70)  NEWLINE()
    WRITES("55 -> ")  notename(55)  NEWLINE()

    FINISH
$)
