# test_ifelse.awk - Test cases for if/else (TODO 10)
# 15 cas : if simple, if/else, imbrique, blocs, expressions

BEGIN {
    x = 10
    y = 20

    # Cas 1 : if simple sans accolades
    if (x > 5)
        print "x > 5"

    # Cas 2 : if simple avec accolades
    if (x == 10) {
        print "x == 10"
    }

    # Cas 3 : if / else sans accolades
    if (x > 100)
        print "x > 100"
    else
        print "x <= 100"

    # Cas 4 : if / else avec accolades
    if (y == 20) {
        print "y == 20"
    } else {
        print "y != 20"
    }

    # Cas 5 : if / else if / else
    z = 3
    if (z == 1) {
        print "z == 1"
    } else if (z == 2) {
        print "z == 2"
    } else if (z == 3) {
        print "z == 3"
    } else {
        print "z autre"
    }

    # Cas 6 : if imbrique
    if (x > 0) {
        if (y > 0) {
            print "x et y positifs"
        }
    }

    # Cas 7 : condition avec operateur logique
    if (x > 0 && y > 0)
        print "les deux positifs"

    # Cas 8 : condition avec operateur ||
    if (x > 100 || y > 10)
        print "au moins un vrai"

    # Cas 9 : if avec expression complexe
    a = x + y
    if (a == 30)
        print "x + y == 30"

    # Cas 10 : if avec comparaison de chaines
    s = "hello"
    if (s == "hello")
        print "s est hello"

    # Cas 11 : if avec assignation dans la condition
    if (n = x * 2)
        print "n = " n

    # Cas 12 : if avec negation
    if (!0)
        print "!0 est vrai"

    # Cas 13 : if / else sur une seule ligne (style compact)
    if (x > 5) print "compact vrai"
    else print "compact faux"

    # Cas 14 : if avec bloc contenant print et expressions
    if (x == 10) {
        a = x * 3
        b = y / 2
        print "a=" a " b=" b
    }

    # Cas 15 : if deeply nested (3 niveaux)
    if (1) {
        if (2) {
            if (3) {
                print "triple imbrique OK"
            }
        }
    }

    print "--- fin test_ifelse ---"
}
