# test_emit22.awk - Test generation en-tete ASM et segment .DATA (TODO 22)
# 15 cas de test pour valider EmitHeader, EmitDataSeg, EmitFooter

# Cas 1 : en-tete ASM genere (.386, .MODEL, EXTRN)
BEGIN {
    print "cas 1: en-tete ASM"
}

# Cas 2 : variable scalaire utilisateur -> DD 0 dans .DATA
BEGIN {
    myvar = "test"
    print "cas 2: var scalaire -> " myvar
}

# Cas 3 : variable numerique utilisateur -> DD 0 dans .DATA
BEGIN {
    count = 42
    print "cas 3: var numerique -> " count
}

# Cas 4 : tableau associatif utilisateur -> DB 256 DUP(0)
BEGIN {
    arr["key"] = "value"
    print "cas 4: tableau associatif"
}

# Cas 5 : plusieurs litteraux chaine -> DB 'text',0
BEGIN {
    a = "hello"
    b = "world"
    c = "test"
    print "cas 5: litteraux chaines: " a " " b " " c
}

# Cas 6 : utilisation de FS builtin
BEGIN {
    print "cas 6: FS=" FS
}

# Cas 7 : utilisation de OFS et ORS
BEGIN {
    print "cas 7: separateurs"
    print "a", "b", "c"
}

# Cas 8 : utilisation de NR et NF
{
    print "cas 8: NR=" NR " NF=" NF
}

# Cas 9 : utilisation de OFMT et CONVFMT
BEGIN {
    print "cas 9: OFMT=" OFMT " CONVFMT=" CONVFMT
}

# Cas 10 : regex pattern -> DB 'pattern',0
BEGIN {
    if ("hello" ~ /hel/) print "cas 10: regex match"
}

# Cas 11 : tampons runtime dans .DATA
BEGIN {
    print "cas 11: tampons runtime"
}

# Cas 12 : segment _TEXT avec ASSUME
BEGIN {
    print "cas 12: segment code"
}

# Cas 13 : variable assignee en boucle
BEGIN {
    i = 0
    while (i < 3) {
        i = i + 1
    }
    print "cas 13: boucle -> i=" i
}

# Cas 14 : fonction utilisateur definit des variables
function myfunc(a, b) {
    local_result = a + b
    return local_result
}
BEGIN {
    r = myfunc(10, 20)
    print "cas 14: func result=" r
}

# Cas 15 : combinaison complete
BEGIN {
    msg = "test complet"
    nums["one"] = 1
    nums["two"] = 2
    print "cas 15: " msg " -> " nums["one"] "+" nums["two"]
}
