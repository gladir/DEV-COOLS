# format.awk - printf, redirection
# Compile avec : AWK86.EXE format.awk format.asm

BEGIN {
    # Printf avec differents formats
    printf "Nom : %s\n", "Alice"
    printf "Age : %d\n", 30
    printf "Score : %d%%\n", 95

    # Boucle avec printf
    for (i = 1; i <= 5; i++) {
        printf "%d x %d = %d\n", i, i, i * i
    }

    # Redirection vers fichier
    print "Ligne 1" > "output.txt"
    print "Ligne 2" > "output.txt"

    print "Format termine"
}
