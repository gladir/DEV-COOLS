# test_io.raku - Test TODO 12 : ENTREES/SORTIES (say, print, put, get, prompt)
# Compile : RAKU86 test_io.raku test_io.asm

# say avec une chaine
say "Hello, World!";

# say avec un entier
say 42;

# say avec une variable chaine
my $msg = "Bonjour";
say $msg;

# say avec une variable entiere
my $n = 255;
say $n;

# say avec expression arithmetique
my $a = 10;
my $b = 20;
say $a + $b;

# print sans saut de ligne
print "valeur: ";
say 100;

# print avec parentheses
print("test ");
say("OK");

# put (alias de say)
put "put alias";
put 99;

# say avec parentheses
say("entre parentheses");

# say d un booleen
my $flag = True;
say $flag;

# note (ecrit sur stdout dans cette implementation)
note "une note";

# note avec parentheses
note("note parens");

# prompt avec message
my $line = prompt("Entrez quelque chose : ");
say $line;

# get sans argument
my $input = get();
say $input;
