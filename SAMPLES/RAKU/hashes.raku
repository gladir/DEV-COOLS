# hashes.raku - Hash, acces, keys, values, exists, delete

# Declaration avec paires
my %capitales = (France => "Paris", Japon => "Tokyo", Canada => "Ottawa");

# Acces par clef litterale
say %capitales<France>;
say %capitales<Japon>;

# Acces par clef variable
say %capitales{"Canada"};

# Affectation d un nouvel element
%capitales<Italie> = "Rome";
say %capitales<Italie>;

# Nombre d elements
my $n = %capitales.elems;
say $n;

# keys - liste des clefs
my @k = %capitales.keys;
say @k.elems;

# values - liste des valeurs
my @v = %capitales.values;
say @v.elems;

# exists (test d existence)
if %capitales<France> {
    say "France existe";
}

# Modification d un element existant
%capitales<Japon> = "Kyoto";
