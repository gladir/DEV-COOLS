// hello.b - Programme Hello World en BCPL
// Compile avec : BCPL86 hello.b
// Syntaxe BCPL  : blocs $( $), IO via WRITES/WRITEN/NEWLINE

LET start() BE $(
    WRITES("==============================*N")
    WRITES("  Bonjour, Monde !*N")
    WRITES("  Hello, World!*N")
    WRITES("  Hola, Mundo!*N")
    WRITES("==============================*N")
    NEWLINE()
    WRITES("Programme compile avec BCPL86 v1.0*N")
    WRITES("Systeme  : 8086 / DOS (MASM)*N")
    NEWLINE()
    WRITES("Caracteres speciaux BCPL :*N")
    WRITES("  Tabulation -> ici*Tla*N")
    WRITES("  Quotes     -> *"guillemets*"*N")
    WRITES("  Asterisque -> **etoile***N")
$)
