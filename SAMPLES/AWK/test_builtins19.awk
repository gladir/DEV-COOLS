# test_builtins19.awk - Tests pour TODO 19 : Fonctions builtin mathematiques
# 15 cas de test couvrant sin, cos, atan2, exp, log, sqrt, int, rand, srand
# et les stubs systeme (system, close, fflush, mktime, strftime)

BEGIN {
    # Cas 1 : sin(x) - sinus d un entier
    x = sin(90)
    print "cas 1: sin(90) =", x

    # Cas 2 : cos(x) - cosinus d un entier
    x = cos(0)
    print "cas 2: cos(0) =", x

    # Cas 3 : atan2(y, x) - arctangente de y/x
    x = atan2(1, 1)
    print "cas 3: atan2(1,1) =", x

    # Cas 4 : exp(x) - exponentielle
    x = exp(1)
    print "cas 4: exp(1) =", x

    # Cas 5 : log(x) - logarithme naturel
    x = log(100)
    print "cas 5: log(100) =", x

    # Cas 6 : sqrt(x) - racine carree
    x = sqrt(144)
    print "cas 6: sqrt(144) =", x

    # Cas 7 : int(x) - troncature entiere
    x = int(42)
    print "cas 7: int(42) =", x

    # Cas 8 : rand() - nombre aleatoire
    srand(12345)
    x = rand()
    print "cas 8: rand() =", x

    # Cas 9 : srand(x) - initialiser graine avec valeur
    srand(99)
    print "cas 9: srand(99) ok"

    # Cas 10 : srand() - initialiser graine sans argument
    srand()
    print "cas 10: srand() ok"

    # Cas 11 : int avec expression
    x = int(100 + 5)
    print "cas 11: int(100+5) =", x

    # Cas 12 : system(cmd) - stub
    x = system("echo test")
    print "cas 12: system() =", x

    # Cas 13 : close(file) - stub
    x = close("/dev/null")
    print "cas 13: close() =", x

    # Cas 14 : fflush() - stub sans argument
    fflush()
    print "cas 14: fflush() ok"

    # Cas 15 : sqrt avec expression composee
    x = sqrt(16) + sqrt(9)
    print "cas 15: sqrt(16)+sqrt(9) =", x
}
