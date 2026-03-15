# test_emitter.raku - Test de l'emetteur ASM (TODO 07)

# Ce fichier teste que le compilateur produit un fichier ASM valide
# avec les directives MASM standard.

# Declarations simples pour exercer l'emetteur
my $x = 42;
my $y = 10;
my $name = "Raku86";

# Expression simple
my $z = $x + $y;

# Chaine de test
my $greeting = "hello world";
