# test_operators.raku - Test des operateurs et precedence (TODO 04)
# Arithmetiques
my $a = 2 + 3;
my $b = 10 - 4;
my $c = 5 * 6;
my $d = 20 / 3;
my $e = 17 mod 5;
my $f = 2 ** 8;
# Comparaisons numeriques
my $g = 5 == 5;
my $h = 5 != 3;
my $i = 3 < 5;
my $j = 5 >= 5;
my $k = 1 <=> 2;
# Logiques
my $l = True && False;
my $m = False || True;
my $n = Nil // 42;
# Ternaire
my $o = True ?? 1 !! 0;
# Unaires
my $p = -42;
my $q = !False;
my $r = ?0;
# Basse precedence
my $s = True and False;
my $t = False or True;
# Divisibilite
my $u = 10 %% 5;
