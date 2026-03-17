# test_getline20.awk - Test getline et redirections E/S (TODO 20)
# 15 cas de test pour valider ParseGetline et les redirections

# Cas 1 : getline simple (lire depuis stdin dans $0)
BEGIN {
    print "cas 1: getline simple"
}

# Cas 2 : getline avec variable
BEGIN {
    print "cas 2: getline var"
    getline line
}

# Cas 3 : getline < fichier
BEGIN {
    print "cas 3: getline < fichier"
    getline < "/dev/null"
}

# Cas 4 : getline var < fichier
BEGIN {
    print "cas 4: getline var < fichier"
    getline data < "/dev/null"
}

# Cas 5 : getline dans une condition (expression)
BEGIN {
    print "cas 5: getline en expression"
    if ((getline line) > 0) {
        print "lu: " line
    }
}

# Cas 6 : getline dans une boucle while
BEGIN {
    print "cas 6: while getline"
    while ((getline line) > 0) {
        print line
    }
}

# Cas 7 : print avec redirection >
BEGIN {
    print "cas 7: print > fichier"
    print "hello" > "/dev/null"
}

# Cas 8 : print avec redirection >>
BEGIN {
    print "cas 8: print >> fichier"
    print "world" >> "/dev/null"
}

# Cas 9 : printf avec redirection >
BEGIN {
    print "cas 9: printf > fichier"
    printf "%s\n", "test" > "/dev/null"
}

# Cas 10 : printf avec redirection >>
BEGIN {
    print "cas 10: printf >> fichier"
    printf "%d\n", 42 >> "/dev/null"
}

# Cas 11 : next statement
{
    print "cas 11: next"
    if (NR == 1) next
    print $0
}

# Cas 12 : getline retourne 0 ou 1
BEGIN {
    print "cas 12: getline retour"
    r = (getline < "/dev/null")
    print "result: " r
}

# Cas 13 : print multiple args avec redirection
BEGIN {
    print "cas 13: print multi > fichier"
    print "a", "b", "c" > "/dev/null"
}

# Cas 14 : getline simple comme statement
BEGIN {
    print "cas 14: getline statement"
    getline
}

# Cas 15 : combinaison getline et print redir
BEGIN {
    print "cas 15: combinaison"
    getline line < "/dev/null"
    print "done: " line > "/dev/null"
    print "test complet"
}
