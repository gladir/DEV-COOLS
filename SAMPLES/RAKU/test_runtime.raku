# test_runtime.raku - Test TODO 24 : Runtime minimal

# Test des operations de base avec le runtime
my $a = 10;
my $b = 20;
my $c = $a + $b;
say $c;

# Test concatenation de chaines
my $name = "Raku";
say $name;

# Test tableau avec push/pop
my @arr = (1, 2, 3);
say @arr.elems;

# Test hash avec store/lookup
my %h;
%h{"key"} = 42;
say %h{"key"};

# Test sous-routine
sub add($x, $y) {
    return $x + $y;
}
say add(5, 7);

# Test avertissement
warn "test warning";

# Fin
say "Runtime OK";
