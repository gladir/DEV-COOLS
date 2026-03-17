# test_dispatch24.awk - Test TODO 24 : Dispatcher et boucle principale
# Compile avec : AWKCW32 SAMPLES/AWK/test_dispatch24.awk

# Cas 1 : BEGIN avec print
BEGIN {
    print "=== Test TODO 24 : Dispatcher ==="
}

# Cas 2 : Bloc vide
BEGIN {
    ;
}

# Cas 3 : if/else dispatcher
BEGIN {
    x = 10
    if (x > 5)
        print "x > 5"
    else
        print "x <= 5"
}

# Cas 4 : while dispatcher
BEGIN {
    i = 0
    while (i < 3) {
        i = i + 1
    }
    print "while done, i=" i
}

# Cas 5 : for dispatcher
BEGIN {
    for (j = 0; j < 3; j = j + 1) {
        ;
    }
    print "for done, j=" j
}

# Cas 6 : do-while dispatcher
BEGIN {
    k = 0
    do {
        k = k + 1
    } while (k < 3)
    print "do-while done, k=" k
}

# Cas 7 : break et continue dans boucle
BEGIN {
    total = 0
    for (n = 0; n < 10; n = n + 1) {
        if (n == 5)
            break
        if (n == 2)
            continue
        total = total + n
    }
    print "break/continue total=" total
}

# Cas 8 : delete array
BEGIN {
    a[1] = "un"
    a[2] = "deux"
    delete a[1]
    print "delete ok"
}

# Cas 9 : Fonction utilisateur et return
function add(a, b) {
    return a + b
}

# Cas 10 : Appel de fonction
BEGIN {
    r = add(3, 7)
    print "add(3,7)=" r
}

# Cas 11 : printf dispatcher
BEGIN {
    printf "printf test %d\n", 42
}

# Cas 12 : Regle pattern-action (dispatch dans boucle)
NR > 0 {
    print "ligne " NR ": " $0
}

# Cas 13 : Regle avec expression pattern
NR == 1 {
    print "premiere ligne"
}

# Cas 14 : for-in dispatcher
BEGIN {
    b["x"] = 1
    b["y"] = 2
    for (key in b) {
        print "key=" key
    }
}

# Cas 15 : exit avec code de sortie
END {
    print "=== Fin test TODO 24 ==="
    exit 0
}
