# test_runtime23.awk - Test TODO 23 : Point d entree Win32,
# boucle principale et helpers runtime
# Compile avec : AWKCW32 SAMPLES/AWK/test_runtime23.awk

# Cas 1 : Regle BEGIN (executee avant la boucle)
BEGIN {
    print "=== Test TODO 23 : Runtime AWK ==="
    msg = "Hello from BEGIN"
    print msg
    x = 42
    y = 10
    z = x + y
    print z
}

# Cas 2 : Regle action sans pattern (toutes les lignes)
{
    print "ligne: " $0
}

# Cas 3 : Regle avec pattern expression
NR > 0 {
    print "NR=" NR
}

# Cas 4 : Fonction utilisateur
function double(n) {
    return n * 2
}

# Cas 5 : Regle END (executee apres la boucle)
END {
    print "=== Fin du test TODO 23 ==="
    r = double(21)
    print "double(21) = " r
    print "Total lignes : " NR
}
