# regex.awk - Patterns /regexp/, sub, gsub, match
# Compile avec : AWK86.EXE regex.awk regex.asm
# Usage : regex < data.txt

# Afficher les lignes contenant "error"
/error/ {
    print "ERREUR ligne " NR ": " $0
}

# Afficher les lignes contenant "warning"
/warning/ {
    print "AVERTISSEMENT ligne " NR ": " $0
}

BEGIN {
    s = "Hello World Hello"
    n = gsub("Hello", "Bonjour", s)
    print s
    print n " remplacements"

    t = "foo bar baz"
    i = index(t, "bar")
    print "Position de bar : " i

    u = match(t, "baz")
    print "Match baz : " u
}
