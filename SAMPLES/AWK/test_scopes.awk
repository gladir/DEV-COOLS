# test_scopes.awk - Test de la gestion des scopes (TODO 05)
# Compile avec : AWKCW32 test_scopes.awk
#
# Scopes testes : SK_GLOBAL, SK_FUNCTION, SK_RULE, SK_BLOCK, SK_LOOP
# Fonctions de scope : EnterScope/LeaveScope, AllocLocal, CurrentEbpOffset
# Labels : GenScopeLabel, SetExitLabel, FindExitLabel
# Boucles : EnterLoop/LeaveLoop, FindLoopBreak/FindLoopContinue

# Scope global : variables globales
BEGIN {
    # Variables globales dans le scope global
    total = 0
    count = 0
    msg = "hello"

    # Boucle for (SK_LOOP scope)
    for (i = 1; i <= 10; i++) {
        total = total + i
        if (total > 20)
            break
    }

    # Boucle while (SK_LOOP scope)
    while (count < 5) {
        count++
        if (count == 3)
            continue
    }

    # Bloc imbrique
    {
        x = 42
        y = x * 2
    }

    print "total:", total, "count:", count
}

# Scope regle pattern-action (SK_RULE)
/pattern/ {
    line_total = 0
    for (j = 1; j <= NF; j++) {
        line_total = line_total + $j
    }
    print NR, line_total
}

# Scope fonction utilisateur (SK_FUNCTION)
function factorial(n) {
    if (n <= 1)
        return 1
    return n * factorial(n - 1)
}

function fibonacci(n,    a, b, tmp, i) {
    a = 0
    b = 1
    for (i = 2; i <= n; i++) {
        tmp = a + b
        a = b
        b = tmp
    }
    return b
}

# Boucles imbriquees avec break/continue
function nested_loops(rows, cols,    i, j, sum) {
    sum = 0
    for (i = 1; i <= rows; i++) {
        for (j = 1; j <= cols; j++) {
            if (j == 3) continue
            if (i * j > 10) break
            sum = sum + i * j
        }
    }
    return sum
}

END {
    print "factorial(5):", factorial(5)
    print "fibonacci(10):", fibonacci(10)
    print "nested:", nested_loops(4, 5)
}
