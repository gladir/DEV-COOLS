# math.raku - sub, return, recursion, operateurs

# Sous-routine addition
sub add($a, $b) {
    return $a + $b;
}

# Sous-routine multiplication
sub mul($a, $b) {
    return $a * $b;
}

# Factorielle recursive
sub fact($n) {
    if $n <= 1 {
        return 1;
    }
    return $n * fact($n - 1);
}

# Fibonacci recursif
sub fib($n) {
    if $n <= 1 {
        return $n;
    }
    return fib($n - 1) + fib($n - 2);
}

# Tests
say add(3, 4);
say mul(6, 7);
say fact(5);
say fib(8);

# Operateurs
my $a = 15;
my $b = 4;
say $a + $b;
say $a - $b;
say $a * $b;
say $a div $b;
say $a mod $b;
