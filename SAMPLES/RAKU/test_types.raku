# test_types.raku - Test du systeme de types (TODO 06)

# Typage optionnel : Int, Str, Bool, Rat
my Int $x = 42;
my Str $name = "hello";
my Bool $flag = True;

# Coercion numerique
my $n = +$name;

# Coercion chaine
my $s = ~$x;

# Coercion booleenne
my $b = ?$x;

# Arithmetique avec types mixtes
my $sum = $x + 10;
my $prod = $x * 2;

# Comparaisons -> Bool
my $eq = $x == 42;
my $neq = $x != 0;

# Comparaisons chaines -> Bool
my $seq = $name eq "hello";

# Concatenation -> Str
my $greeting = $name ~ " world";
