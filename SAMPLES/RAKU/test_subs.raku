# test_subs.raku - Test TODO 17 : sous-routines et fonctions

# Sub simple sans parametres
sub hello() {
    say "Hello from sub";
}
hello();

# Sub avec un parametre
sub double($n) {
    return $n * 2;
}
my $r = double(21);
say $r;

# Sub avec deux parametres
sub add($a, $b) {
    return $a + $b;
}
my $s = add(10, 32);
say $s;

# Sub avec trois parametres
sub sum3($x, $y, $z) {
    return $x + $y + $z;
}
my $t = sum3(1, 2, 3);
say $t;

# Return implicite (derniere expression)
sub square($n) {
    return $n * $n;
}
say square(5);

# Recursion directe
sub fact($n) {
    if $n <= 1 {
        return 1;
    }
    return $n * fact($n - 1);
}
say fact(5);
