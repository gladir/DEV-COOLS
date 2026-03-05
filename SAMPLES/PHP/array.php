<?php
// ============================================================
// array.php -- Tableaux entiers pour PHP86
// array(), count(), $a[i], foreach
// ============================================================

echo "=== array.php ===\n";

// --- Tableau d'entiers ---
$nums = array(10, 20, 30, 40, 50);
echo "Taille         : ", count($nums), "\n";
echo "Premier   [0]  : ", $nums[0], "\n";
echo "Deuxieme  [1]  : ", $nums[1], "\n";
echo "Cinquieme [4]  : ", $nums[4], "\n";

// --- foreach sans cle ---
echo "foreach vals   : ";
foreach ($nums as $v) {
    echo $v, " ";
}
echo "\n";

// --- foreach avec cle ---
echo "foreach k=>v   : ";
foreach ($nums as $k => $v) {
    echo "[", $k, "]=", $v, " ";
}
echo "\n";

// --- Somme des elements ---
$somme = 0;
foreach ($nums as $v) {
    $somme = $somme + $v;
}
echo "Somme          : ", $somme, "\n";

// --- Minimum et maximum ---
$tmin = $nums[0];
$tmax = $nums[0];
foreach ($nums as $v) {
    if ($v < $tmin) {
        $tmin = $v;
    }
    if ($v > $tmax) {
        $tmax = $v;
    }
}
echo "Min            : ", $tmin, "\n";
echo "Max            : ", $tmax, "\n";

// --- Tableau de Fibonacci (litteral) ---
$fib = array(1, 1, 2, 3, 5, 8, 13, 21);
echo "Fibonacci[0]   : ", $fib[0], "\n";
echo "Fibonacci[6]   : ", $fib[6], "\n";
echo "Fibonacci[7]   : ", $fib[7], "\n";
echo "Nb elements    : ", count($fib), "\n";

// --- Tableau avec syntaxe courte [] ---
$squares = [1, 4, 9, 16, 25];
echo "Carres[2]      : ", $squares[2], "\n";
echo "Carres[4]      : ", $squares[4], "\n";

echo "=== Fin array.php ===\n";
