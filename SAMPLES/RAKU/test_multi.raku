# test_multi.raku - Test TODO 18 : multi dispatch

# Multi sub dispatche sur le type du premier argument
multi sub greet(Int $n) {
    say $n;
}
multi sub greet(Str $s) {
    say $s;
}

# Appels avec differents types
greet(42);
greet("Hello");

# Multi sub avec candidat par defaut
multi sub show(Int $x) {
    return $x * 10;
}
multi sub show($x) {
    return $x;
}

my $a = show(5);
say $a;

# Proto sub (declaration optionnelle du prototype)
proto sub compute(|) {*}
multi sub compute(Int $x) {
    return $x + 100;
}
my $b = compute(7);
say $b;
