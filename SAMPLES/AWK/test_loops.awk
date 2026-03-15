# test_loops.awk - Test cases for while/for/do-while/break/continue (TODO 11)
# 20 cas : while, for, do-while, break, continue, imbriques

BEGIN {
    # Cas 1 : while simple
    i = 0
    while (i < 5)
        i = i + 1
    print "cas1: i=" i

    # Cas 2 : while avec bloc
    j = 1
    while (j <= 10) {
        j = j * 2
    }
    print "cas2: j=" j

    # Cas 3 : for simple (C-style)
    s = 0
    for (k = 1; k <= 5; k = k + 1)
        s = s + k
    print "cas3: s=" s

    # Cas 4 : for avec bloc
    total = 0
    for (n = 0; n < 10; n = n + 1) {
        total = total + n
    }
    print "cas4: total=" total

    # Cas 5 : do-while simple
    x = 1
    do
        x = x * 2
    while (x < 100)
    print "cas5: x=" x

    # Cas 6 : do-while avec bloc
    y = 10
    do {
        y = y - 3
    } while (y > 0)
    print "cas6: y=" y

    # Cas 7 : while avec break
    m = 0
    while (1) {
        m = m + 1
        if (m >= 5)
            break
    }
    print "cas7: m=" m

    # Cas 8 : for avec break
    last = 0
    for (i = 0; i < 100; i = i + 1) {
        if (i == 7)
            break
        last = i
    }
    print "cas8: last=" last

    # Cas 9 : while avec continue
    cnt = 0
    i = 0
    while (i < 10) {
        i = i + 1
        if (i % 2 == 0)
            continue
        cnt = cnt + 1
    }
    print "cas9: cnt=" cnt

    # Cas 10 : for avec continue
    odd_sum = 0
    for (i = 1; i <= 10; i = i + 1) {
        if (i % 2 == 0)
            continue
        odd_sum = odd_sum + i
    }
    print "cas10: odd_sum=" odd_sum

    # Cas 11 : boucles imbriquees (while dans while)
    count = 0
    i = 0
    while (i < 3) {
        j = 0
        while (j < 4) {
            count = count + 1
            j = j + 1
        }
        i = i + 1
    }
    print "cas11: count=" count

    # Cas 12 : boucles imbriquees (for dans for)
    sum = 0
    for (i = 1; i <= 3; i = i + 1) {
        for (j = 1; j <= 3; j = j + 1) {
            sum = sum + i * j
        }
    }
    print "cas12: sum=" sum

    # Cas 13 : while dans for
    r = 0
    for (i = 1; i <= 3; i = i + 1) {
        v = i
        while (v > 0) {
            r = r + 1
            v = v - 1
        }
    }
    print "cas13: r=" r

    # Cas 14 : for dans while
    w = 0
    i = 0
    while (i < 2) {
        for (j = 0; j < 3; j = j + 1)
            w = w + 1
        i = i + 1
    }
    print "cas14: w=" w

    # Cas 15 : do-while dans for
    acc = 0
    for (i = 1; i <= 3; i = i + 1) {
        v = 0
        do {
            v = v + 1
            acc = acc + 1
        } while (v < i)
    }
    print "cas15: acc=" acc

    # Cas 16 : break dans boucle imbriquee (break sort de la boucle interne)
    found = 0
    for (i = 1; i <= 5; i = i + 1) {
        for (j = 1; j <= 5; j = j + 1) {
            if (j == 3)
                break
        }
        found = found + 1
    }
    print "cas16: found=" found

    # Cas 17 : for sans init
    i = 0
    for (; i < 5; i = i + 1) {
        # corps vide est ok
    }
    print "cas17: i=" i

    # Cas 18 : for avec condition vide (boucle infinie + break)
    c = 0
    for (i = 0; ; i = i + 1) {
        c = c + 1
        if (c >= 3)
            break
    }
    print "cas18: c=" c

    # Cas 19 : if dans while
    pos = 0
    neg = 0
    i = -5
    while (i <= 5) {
        if (i > 0)
            pos = pos + 1
        else if (i < 0)
            neg = neg + 1
        i = i + 1
    }
    print "cas19: pos=" pos " neg=" neg

    # Cas 20 : triple imbrication
    t = 0
    for (i = 0; i < 2; i = i + 1) {
        for (j = 0; j < 2; j = j + 1) {
            for (k = 0; k < 2; k = k + 1) {
                t = t + 1
            }
        }
    }
    print "cas20: t=" t

    print "--- fin test_loops ---"
}
