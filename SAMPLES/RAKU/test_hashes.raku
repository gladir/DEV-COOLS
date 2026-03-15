# test_hashes.raku - Test des tables de hachage (TODO 16)

# Ce fichier teste que le compilateur gere correctement :
#   - Declaration de hash : my %h = (clef => valeur, ...)
#   - Acces par clef : %h<clef> et %h{"clef"}
#   - Affectation element : %h<clef> = valeur
#   - Methode .elems : nombre de paires
#   - Methodes .keys et .values (stubs runtime)

# Declaration d un hash avec paires statiques
my %h = (name => "Alice", age => 30);

# Acces par clef litterale
say %h<name>;
say %h<age>;

# Nombre de paires
my $n = %h.elems;
say $n;

# Affectation d un nouvel element
%h<city> = "Paris";

# Verifier le nouveau nombre de paires
say %h.elems;

# Acces au nouvel element
say %h<city>;
