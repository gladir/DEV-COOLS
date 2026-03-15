# arrays.raku - Array, push, pop, sort, reverse, join, elems

# Declaration
my @nombres = (10, 20, 30, 40, 50);

# Acces par index
say @nombres[0];
say @nombres[2];

# Nombre d elements
my $n = @nombres.elems;
say $n;

# push - ajout en fin
@nombres.push(60);

# pop - retrait en fin
my $dernier = @nombres.pop;
say $dernier;

# reverse
@nombres.reverse;

# sort
my @desordonnes = (50, 10, 40, 20, 30);
@desordonnes.sort;

# join - concatenation avec separateur
my @mots = ("Raku", "est", "genial");
my $phrase = @mots.join(" ");
say $phrase;

# Parcours avec for
for @nombres -> $v {
    say $v;
}
