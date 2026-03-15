# test_print.awk - Test print, printf, sprintf (TODO 09)
# Compile avec : AWKCW32 test_print.awk

BEGIN {
    # ---- Test 1 : print sans argument (affiche $0) ----
    print

    # ---- Test 2 : print une chaine ----
    print "Hello, World!"

    # ---- Test 3 : print un nombre ----
    print 42

    # ---- Test 4 : print une variable chaine ----
    msg = "Bonjour"
    print msg

    # ---- Test 5 : print une variable nombre ----
    x = 100
    print x

    # ---- Test 6 : print avec expression ----
    print 2 + 3

    # ---- Test 7 : print avec plusieurs arguments (separes par OFS) ----
    print "nom", "age", "score"

    # ---- Test 8 : print avec plus de 2 arguments ----
    print 1, 2, 3, 4, 5

    # ---- Test 9 : print avec expression complexe ----
    a = 10
    b = 20
    print a + b, a * b, a - b

    # ---- Test 10 : printf format %d ----
    printf "%d\n", 42

    # ---- Test 11 : printf format %s ----
    printf "%s\n", "texte"

    # ---- Test 12 : printf format multiple ----
    printf "x=%d y=%d\n", 10, 20

    # ---- Test 13 : printf %% litteral ----
    printf "Score: %d%%\n", 95

    # ---- Test 14 : sprintf dans une expression ----
    result = sprintf("valeur=%d", 42)
    print result

    # ---- Test 15 : sprintf avec plusieurs arguments ----
    s = sprintf("%s a %d ans", "Alice", 30)
    print s

    # ---- Test 16 : print avec redirection > (stub) ----
    print "ligne de test" > "output.txt"

    # ---- Test 17 : printf sans argument supplementaire ----
    printf "pas de format\n"

    # ---- Test 18 : print chaine vide ----
    print ""

    # ---- Test 19 : print combinaison nombre et chaine ----
    print "valeur:", 42

    # ---- Test 20 : sprintf imbrique dans print ----
    print sprintf("n=%d", 7)
}
