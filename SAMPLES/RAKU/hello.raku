# hello.raku - say, print, variables scalaires, Str, Int

# Salutation simple
say "Hello, World!";

# Variables entieres
my $x = 42;
my $y = 8;
say $x;
say $y;

# Variable avec type
my Int $age = 25;
say $age;

# Variable chaine
my Str $name = "Raku";
say $name;

# print (sans saut de ligne) + say
print "valeur = ";
say $x;

# Expressions arithmetiques simples
my $sum = $x + $y;
say $sum;

# put (alias de say)
put "Fin du programme hello";
