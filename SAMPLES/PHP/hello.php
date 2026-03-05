<?php
// ============================================================
// hello.php -- Demo de base pour PHP86
// echo, variables, constantes, arithmetique
// ============================================================

define('APP_NAME', 'PHP86');
define('APP_VER',  1);

echo "=== Hello, World! ===\n";

$nom = "DOS";
echo "Bonjour depuis ";
echo APP_NAME;
echo " pour ";
echo $nom;
echo "\n";

$annee = 2026;
echo "Annee    : ", $annee, "\n";
echo "Version  : ", APP_VER, "\n";
echo "OS cible : ", PHP_OS, "\n";
echo "INT_MAX  : ", PHP_INT_MAX, "\n";

// Operateurs arithmetiques de base
$a = 10;
$b = 3;
echo $a, " + ", $b, " = ", $a + $b, "\n";
echo $a, " - ", $b, " = ", $a - $b, "\n";
echo $a, " * ", $b, " = ", $a * $b, "\n";
echo $a, " / ", $b, " = ", $a / $b, "\n";
echo $a, " % ", $b, " = ", $a % $b, "\n";

// Operateurs de comparaison (retourne 0 ou 1)
echo "10 > 3  : ", ($a > $b), "\n";
echo "10 == 3 : ", ($a == $b), "\n";
echo "10 != 3 : ", ($a != $b), "\n";

// Constante avec mot-cle const
const MAX_ITER = 5;
echo "MAX_ITER : ", MAX_ITER, "\n";

echo "=== Fin hello.php ===\n";
