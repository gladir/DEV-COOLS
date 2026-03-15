# test_concat.awk - Test concatenation de chaines et coercition
# TODO 07 de AWKCW32

# 1. Concatenation implicite de deux chaines litterales
BEGIN {
    a = "hello" " " "world"
    print a
}

# 2. Concatenation implicite chaine + variable
{
    prefix = "item:"
    result = prefix $1
    print result
}

# 3. Concatenation nombre + chaine (coercition nombre -> chaine)
BEGIN {
    x = 42
    msg = "value=" x
    print msg
}

# 4. Concatenation chaine + nombre (coercition nombre -> chaine)
BEGIN {
    y = 100
    line = "count is " y " items"
    print line
}

# 5. Coercition chaine -> nombre (contexte arithmetique)
BEGIN {
    s = "123"
    n = s + 1
    print n
}

# 6. Coercition chaine -> nombre (contexte multiplication)
BEGIN {
    a = "10"
    b = "3"
    c = a * b
    print c
}

# 7. Coercition chaine -> nombre (contexte division)
BEGIN {
    a = "100"
    b = "4"
    c = a / b
    print c
}

# 8. Coercition chaine -> nombre (contexte modulo)
BEGIN {
    a = "17"
    b = "5"
    c = a % b
    print c
}

# 9. Coercition chaine -> nombre (contexte puissance)
BEGIN {
    a = "2"
    b = "10"
    c = a ^ b
    print c
}

# 10. Coercition booleenne (&&)
BEGIN {
    a = "hello"
    b = 1
    if (a && b)
        print "both true"
}

# 11. Coercition booleenne (||)
BEGIN {
    a = ""
    b = 42
    if (a || b)
        print "at least one true"
}

# 12. Coercition booleenne (!)
BEGIN {
    a = "non-empty"
    if (!a)
        print "empty"
}

# 13. Concatenation implicite avec unaire
BEGIN {
    x = 5
    result = "neg=" -x
    print result
}

# 14. Concatenation multiple
BEGIN {
    a = "A"
    b = "B"
    c = "C"
    result = a b c
    print result
}

# 15. Comparaison mixte (nombre vs chaine)
BEGIN {
    x = 42
    s = "42"
    if (x == s)
        print "equal"
}

# 16. Comparaison chaine vs chaine
BEGIN {
    a = "abc"
    b = "def"
    if (a < b)
        print "abc < def"
}

# 17. Concatenation avec champ $
{
    msg = "field1=" $1 " field2=" $2
    print msg
}

# 18. Coercition unaire + (forcer en nombre)
BEGIN {
    s = "99"
    n = +s
    print n
}

# 19. Coercition avec variable non initialisee
BEGIN {
    result = uninit_var + 1
    print result
}

# 20. Concatenation dans print
BEGIN {
    print "hello" " " "world"
}

END {
    print "test_concat done"
}
