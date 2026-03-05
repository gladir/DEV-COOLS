<?php
// ============================================================
// control.php -- Structures de controle pour PHP86
// if/elseif/else, while, for, foreach, switch, break, continue
// ============================================================

echo "=== control.php ===\n";

// --- If / elseif / else ---
$n = 42;
echo "n = ", $n, "\n";
if ($n > 100) {
    echo "grand\n";
} elseif ($n > 10) {
    echo "moyen\n";
} else {
    echo "petit\n";
}

// --- While ---
echo "while 1..5 : ";
$i = 1;
while ($i <= 5) {
    echo $i, " ";
    $i = $i + 1;
}
echo "\n";

// --- Do-While ---
echo "do-while 3..1 : ";
$j = 3;
do {
    echo $j, " ";
    $j = $j - 1;
} while ($j > 0);
echo "\n";

// --- For ---
echo "for 0..4 : ";
for ($k = 0; $k < 5; $k++) {
    echo $k, " ";
}
echo "\n";

// --- For avec break ---
echo "for break a 3 : ";
for ($m = 0; $m < 10; $m++) {
    if ($m == 3) {
        break;
    }
    echo $m, " ";
}
echo "\n";

// --- For avec continue ---
echo "for impairs 0..9 : ";
for ($p = 0; $p < 10; $p++) {
    if ($p % 2 == 0) {
        continue;
    }
    echo $p, " ";
}
echo "\n";

// --- Switch ---
$code = 2;
echo "switch(", $code, ") : ";
switch ($code) {
    case 1:
        echo "un\n";
        break;
    case 2:
        echo "deux\n";
        break;
    case 3:
        echo "trois\n";
        break;
    default:
        echo "autre\n";
}

// --- Operateurs logiques ---
$a = 1;
$b = 0;
echo "a && b = ", ($a && $b), "\n";
echo "a || b = ", ($a || $b), "\n";
echo "!a     = ", (!$a), "\n";

echo "=== Fin control.php ===\n";
