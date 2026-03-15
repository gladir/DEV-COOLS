# test_data.raku - Test du segment de donnees (TODO 08)

# Ce fichier teste que le compilateur produit un fichier ASM valide
# avec un segment DATA correctement pre-peuple :
#   - Constantes CRLF, NL, SPACE, chaine vide
#   - True, False, Nil comme chaines
#   - Buffers STRBUF, TMPBUF, NUMBUF

# Declarations exercant DataAddStr
my $msg = "hello world";
my $name = "Raku86";

# Variables simples
my $x = 42;
my $y = 10;

# Expression simple
my $z = $x + $y;

# Chaine avec caracteres speciaux
my $greeting = "bonjour";
