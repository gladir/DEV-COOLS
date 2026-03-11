# arrays.awk - Tableaux associatifs, for-in, delete
# Compile avec : AWK86.EXE arrays.awk arrays.asm

BEGIN {
    # Creer un tableau
    fruit["pomme"] = 3
    fruit["banane"] = 5
    fruit["orange"] = 2

    # Parcourir avec for-in
    for (key in fruit) {
        print key " : " fruit[key]
    }

    # Tester l existence
    if ("pomme" in fruit)
        print "pomme existe"

    # Supprimer une entree
    delete fruit["banane"]

    print "Apres suppression :"
    for (key in fruit) {
        print key " : " fruit[key]
    }
}
