<?php
// ============================================================
// math.php -- Fonctions, arithmetique, return pour PHP86
// ============================================================

// Fonction : carre d'un nombre
function carre($n) {
    return $n * $n;
}

// Fonction : addition
function somme($a, $b) {
    return $a + $b;
}

// Fonction : factorielle iterative
function factorielle($n) {
    $r = 1;
    $i = 1;
    while ($i <= $n) {
        $r = $r * $i;
        $i = $i + 1;
    }
    return $r;
}

// Fonction : PGCD (algorithme d'Euclide)
function pgcd($a, $b) {
    while ($b != 0) {
        $t = $b;
        $b = $a % $b;
        $a = $t;
    }
    return $a;
}

// Fonction : valeur absolue maison
function mon_abs($n) {
    if ($n < 0) {
        return 0 - $n;
    }
    return $n;
}

echo "=== math.php ===\n";

$x = 6;
$y = 4;

echo "carre(", $x, ")       = ", carre($x), "\n";
echo "somme(", $x, ", ", $y, ") = ", somme($x, $y), "\n";
echo "factorielle(5)  = ", factorielle(5), "\n";
echo "factorielle(7)  = ", factorielle(7), "\n";
echo "pgcd(48, 18)    = ", pgcd(48, 18), "\n";
echo "mon_abs(-42)    = ", mon_abs(-42), "\n";

// Builtins mathematiques
echo "abs(-99)        = ", abs(-99), "\n";
echo "max(", $x, ", ", $y, ")   = ", max($x, $y), "\n";
echo "min(", $x, ", ", $y, ")   = ", min($x, $y), "\n";

// Puissance (operateur ** ou _PHRT_POWER)
$base = 2;
$exp  = 8;
echo $base, " ** ", $exp, " = ", $base ** $exp, "\n";

echo "=== Fin math.php ===\n";
