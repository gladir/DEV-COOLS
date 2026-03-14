# test_variables.raku - Test des variables et affectations (TODO 09)

# Ce fichier teste que le compilateur gere correctement :
#   - Variables my scalaires ($x) : pile [BP-offset]
#   - Variables our scalaires ($x) : segment DATA _RKV_nom
#   - Declarateur constant
#   - Typage optionnel (my Int $x)
#   - Affectation = et affectation composee +=, -=, *=, /=
#   - Binding :=

# Variables my avec valeur par defaut
my $x = 42;
my $y = 10;

# Variable my avec type optionnel
my Int $z = 100;

# Variable our (globale)
our $global = 7;

# Constante
constant $PI = 314;

# Affectation simple
$x = 5;

# Affectation composee
$y += 3;
$x -= 1;
$z *= 2;

# Binding (alias)
my $a := $x;

# Chaines
my $name = "Raku86";
my Str $greeting = "hello";

# Expression combinee
my $sum = $x + $y + $z;
