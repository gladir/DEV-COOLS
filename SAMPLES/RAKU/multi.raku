# multi.raku - multi sub, dispatch, proto

# Multi sub avec dispatch sur le type
multi sub affiche(Int $n) {
    say $n;
}

multi sub affiche(Str $s) {
    say $s;
}

# Appels dispatches
affiche(42);
affiche("Bonjour");

# Proto sub (prototype)
proto sub calcul(|) {*}

multi sub calcul(Int $x) {
    return $x * 2;
}

multi sub calcul(Int $x, Int $y) {
    return $x + $y;
}

# Appels
say calcul(10);
say calcul(3, 7);

# Multi sub sur nombre de parametres
multi sub zero() {
    say "zero args";
}

multi sub zero(Int $a) {
    say $a;
}

zero();
zero(99);
