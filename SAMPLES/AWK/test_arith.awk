# test_arith.awk - Test des operations arithmetiques (TODO 08)
# Compile avec : AWKCW32 test_arith.awk

BEGIN {
    # Constantes entieres et flottantes
    a = 10
    b = 3

    # Operations binaires
    print a + b
    print a - b
    print a * b
    print a / b
    print a % b
    print 2 ^ 8

    # Operations unaires
    c = -a
    print c
    d = !0
    print d
    e = !1
    print e

    # Increment / decrement prefixe et suffixe
    x = 5
    ++x
    print x
    --x
    print x
    x++
    print x
    x--
    print x

    # Comparaisons
    print (a < b)
    print (a <= b)
    print (a > b)
    print (a >= b)
    print (a == b)
    print (a != b)
    print (3 == 3)
    print (3 != 3)

    # Affectation composee
    y = 10
    y += 5
    y -= 2
    y *= 3
    y /= 2
    y %= 7
    y ^= 2
    print y

    # Reference de champ
    print $1
    print $0
}
