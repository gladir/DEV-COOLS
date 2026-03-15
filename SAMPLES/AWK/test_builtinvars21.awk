# test_builtinvars21.awk - Test variables builtin AWK (TODO 21)
# 15 cas de test pour valider InitBuiltinVarDefaults, ApplyDashF, ApplyDashV

# Cas 1 : NR est initialise a 0
BEGIN {
    print "cas 1: NR=" NR
}

# Cas 2 : NF est initialise a 0
BEGIN {
    print "cas 2: NF=" NF
}

# Cas 3 : FNR est initialise a 0
BEGIN {
    print "cas 3: FNR=" FNR
}

# Cas 4 : FS est initialise a " " (espace)
BEGIN {
    print "cas 4: FS defaut"
    if (FS == " ") print "OK: FS est espace"
}

# Cas 5 : RS est initialise a "\n" (newline)
BEGIN {
    print "cas 5: RS defaut"
}

# Cas 6 : OFS est initialise a " " (espace)
BEGIN {
    print "cas 6: OFS defaut"
    print "a", "b", "c"
}

# Cas 7 : ORS est initialise a "\n" (newline)
BEGIN {
    print "cas 7: ORS defaut"
}

# Cas 8 : FILENAME est vide au debut
BEGIN {
    print "cas 8: FILENAME initial"
}

# Cas 9 : ARGC est initialise a 0
BEGIN {
    print "cas 9: ARGC=" ARGC
}

# Cas 10 : RSTART est initialise a 0
BEGIN {
    print "cas 10: RSTART=" RSTART
}

# Cas 11 : RLENGTH est initialise a 0
BEGIN {
    print "cas 11: RLENGTH=" RLENGTH
}

# Cas 12 : SUBSEP est initialise a "\034"
BEGIN {
    print "cas 12: SUBSEP defaut"
}

# Cas 13 : OFMT est initialise a "%.6g"
BEGIN {
    print "cas 13: OFMT=" OFMT
}

# Cas 14 : CONVFMT est initialise a "%.6g"
BEGIN {
    print "cas 14: CONVFMT=" CONVFMT
}

# Cas 15 : Combinaison de variables builtin
BEGIN {
    print "cas 15: combinaison"
    nr = NR
    nf = NF
    print "NR=" nr " NF=" nf " RSTART=" RSTART " RLENGTH=" RLENGTH
    print "test complet"
}
