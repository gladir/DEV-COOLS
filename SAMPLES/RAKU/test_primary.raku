# test_primary.raku - Test des expressions primaires (TODO 10)

# Ce fichier teste que le compilateur gere correctement :
#   - Appel de sous-routine : name(args)
#   - Acces attribut : $obj.attr
#   - Acces methode : $obj.methode(args)
#   - Construction de paire : clef => valeur
#   - self dans une methode
#   - Chaine de postfixes : $obj.method1.method2
#   - Instanciation : Classe.new

# Variables de base
my $x = 10;
my $y = 20;

# Appel de sous-routine avec arguments
my $sum = add($x, $y);

# Appel sans arguments
my $val = get_value();

# Construction de paires
my $pair = name => 42;
my $pair2 = color => "blue";

# Acces attribut et methode (stub via postfix)
my $obj = 0;
$obj.method1;
$obj.method2(10);
$obj.attr;

# self (reference objet courant)
self.init;

# Instanciation de classe
my $p = Point.new(1, 2);
my $q = Point.new;

# Chaine de postfixes
$obj.method1.method2;

# Coercions contextuelles via prefixes
my $n = +$x;
my $s = ~$x;
my $b = ?$x;
my $b2 = so $x;
my $b3 = not $x;

# Paire avec expression
my $kv = answer => $x + 32;
