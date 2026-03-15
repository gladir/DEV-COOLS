# test_builtins18.awk - Test des fonctions builtin chaines (TODO 18)
# 15 cas de test pour les fonctions : length, substr, index, split,
# sub, gsub, match, sprintf, tolower, toupper

BEGIN {
    # Cas 1 : length d une chaine
    s = "Hello World"
    n = length(s)
    print "Cas 1 - length(s):", n

    # Cas 2 : length sans parentheses (implicite $0)
    print "Cas 2 - length implicite"

    # Cas 3 : substr avec 2 arguments (s, start)
    r = substr("abcdef", 3)
    print "Cas 3 - substr(s,3):", r

    # Cas 4 : substr avec 3 arguments (s, start, len)
    r = substr("abcdef", 2, 3)
    print "Cas 4 - substr(s,2,3):", r

    # Cas 5 : index - trouver une sous-chaine
    p = index("Hello World", "World")
    print "Cas 5 - index:", p

    # Cas 6 : index - sous-chaine non trouvee
    p = index("Hello", "xyz")
    print "Cas 6 - index not found:", p

    # Cas 7 : tolower
    r = tolower("HELLO WORLD")
    print "Cas 7 - tolower:", r

    # Cas 8 : toupper
    r = toupper("hello world")
    print "Cas 8 - toupper:", r

    # Cas 9 : match avec regex
    p = match("Hello 123 World", /[0-9]+/)
    print "Cas 9 - match:", p

    # Cas 10 : sprintf
    r = sprintf("valeur=%d texte=%s", 42, "abc")
    print "Cas 10 - sprintf:", r

    # Cas 11 : sub - premiere substitution
    s = "aaa bbb aaa"
    n = sub(/aaa/, "xxx", s)
    print "Cas 11 - sub:", n, s

    # Cas 12 : gsub - substitution globale
    s = "aaa bbb aaa ccc aaa"
    n = gsub(/aaa/, "X", s)
    print "Cas 12 - gsub:", n, s

    # Cas 13 : split
    s = "un:deux:trois:quatre"
    n = split(s, arr, ":")
    print "Cas 13 - split:", n

    # Cas 14 : length d un tableau
    delete arr
    arr["a"] = 1
    arr["b"] = 2
    arr["c"] = 3
    n = length(arr)
    print "Cas 14 - length(array):", n

    # Cas 15 : combinaison de builtins
    s = toupper(substr("hello world", 1, 5))
    print "Cas 15 - combine:", s
}
