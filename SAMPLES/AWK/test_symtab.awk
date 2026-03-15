# test_symtab.awk - Test de la table des symboles (TODO 04)
# Compile avec : AWKCW32 test_symtab.awk

# Variables builtin AWK (12 pre-declarees)
# FS, RS, OFS, ORS, NR, NF, FNR, FILENAME,
# ARGC, RSTART, RLENGTH, SUBSEP

BEGIN {
    # Test des variables builtin
    FS = ":"
    OFS = " "
    ORS = "\n"
    RS = "\n"

    # Variables utilisateur (ajoutees par le parseur)
    x = 42
    msg = "hello"
    total = 0

    # Tableau associatif
    arr[1] = "un"
    arr[2] = "deux"

    # Variables builtin numeriques
    print NR, NF, FNR

    # Variables builtin chaines
    print FILENAME
    print FS, RS, OFS, ORS

    # Fonctions utilisateur
    print length("test")
    print substr("abcdef", 2, 3)
    print toupper("hello")
    print tolower("WORLD")
}

# Regle pattern-action avec variables
/pattern/ {
    total = total + 1
    print NR, NF, $0
}

# Fonction utilisateur
function max(a, b) {
    if (a > b) return a
    return b
}

function min(a, b) {
    if (a < b) return a
    return b
}

END {
    print "Total:", total
    print "Max:", max(10, 20)
    print "RSTART:", RSTART
    print "RLENGTH:", RLENGTH
    print "SUBSEP:", SUBSEP
    print "ARGC:", ARGC
}
