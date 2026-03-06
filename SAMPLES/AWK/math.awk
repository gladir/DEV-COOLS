# math.awk - Fonctions mathematiques, expressions
# Compile avec : AWK86.EXE math.awk math.asm

BEGIN {
    print "Racine de 144 = " sqrt(144)
    print "Racine de 256 = " sqrt(256)
    print "Int de 7 = " int(7)

    # Puissance : 2^10
    x = 2
    y = 10
    print x " ^ " y " = " x ^ y

    # Aleatoire
    srand(42)
    print "Rand 1 = " rand()
    print "Rand 2 = " rand()
    print "Rand 3 = " rand()

    # Exp et log (approximations entieres)
    print "Exp(3) = " exp(3)
    print "Log(27) = " log(27)

    # Arithmetique
    a = 100
    b = 7
    print a " / " b " = " a / b
    print a " % " b " = " a % b
}
