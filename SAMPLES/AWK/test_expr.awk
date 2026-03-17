# test_expr.awk - test pour TODO 06 PARSEUR EXPRESSIONS
# Teste toutes les categories d expressions AWK

BEGIN {
    # --- Constantes numeriques ---
    a = 42
    b = 0
    c = 3.14
    d = 0xFF
    e = 077

    # --- Constantes chaines ---
    s1 = "hello"
    s2 = "world"
    s3 = ""

    # --- Arithmetique de base (+, -, *, /, %) ---
    x = 10 + 20
    y = 100 - 50
    z = 6 * 7
    q = 100 / 3
    r = 17 % 5

    # --- Puissance (^) droite a gauche ---
    p = 2 ^ 10
    p2 = 2 ^ 3 ^ 2

    # --- Operateurs unaires (-, +, !) ---
    neg = -42
    pos = +10
    notv = !0
    notv2 = !1

    # --- Pre-increment / Pre-decrement ---
    i = 5
    ++i
    --i

    # --- Post-increment / Post-decrement ---
    j = 10
    j++
    j--

    # --- Comparaisons (<, <=, >, >=, ==, !=) ---
    t1 = (10 < 20)
    t2 = (10 <= 10)
    t3 = (20 > 10)
    t4 = (20 >= 20)
    t5 = (5 == 5)
    t6 = (5 != 3)

    # --- Operateurs logiques (&&, ||) ---
    and1 = (1 && 1)
    and2 = (1 && 0)
    or1 = (0 || 1)
    or2 = (0 || 0)

    # --- Operateur ternaire (? :) ---
    max = (10 > 5) ? 10 : 5
    min = (10 < 5) ? 10 : 5

    # --- Affectation composee (+=, -=, *=, /=, %=, ^=) ---
    v = 10
    v += 5
    v -= 3
    v *= 2
    v /= 4
    v %= 3
    v ^= 2

    # --- Affectation simple ---
    w = v

    # --- Concatenation implicite ---
    msg = "abc" "def"
    msg2 = "x" 42 "y"
    msg3 = s1 " " s2

    # --- Appels de fonctions builtin ---
    l = length("hello")
    s = substr("hello world", 1, 5)
    idx = index("hello", "ell")
    lo = tolower("HELLO")
    up = toupper("hello")

    # --- sprintf ---
    fmt = sprintf("%d + %d = %d", 1, 2, 3)

    # --- Expressions avec parentheses ---
    res = (1 + 2) * (3 + 4)
    res2 = ((10 - 5) * 2) + 1

    # --- Operateur match (~, !~) ---
    m1 = ("hello" ~ /ell/)
    m2 = ("hello" !~ /xyz/)

    # --- Operateur in ---
    arr[1] = "a"
    arr[2] = "b"
    t7 = (1 in arr)

    # --- Reference de champ $n ---
    print $0
    print $1, $2, $NF

    # --- Expressions complexes combinees ---
    big = (a + b) * c - (d / e) + (x % y)
    cond = (a > 0 && b >= 0) || (c != 0)

    # --- Appel de fonction utilisateur ---
    result = myfunc(10, 20, 30)

    print "test_expr OK"
}

# Fonction utilisateur pour test
function myfunc(a, b, c) {
    return a + b + c
}
