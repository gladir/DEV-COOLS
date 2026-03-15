# control.raku - if/elsif/else, unless, given/when, ternaire

my $x = 10;

# if simple
if $x > 0 {
    say "positif";
}

# if / else
if $x > 100 {
    say "grand";
} else {
    say "petit";
}

# if / elsif / else
my $note = 75;
if $note >= 90 {
    say "excellent";
} elsif $note >= 70 {
    say "bien";
} elsif $note >= 50 {
    say "passable";
} else {
    say "insuffisant";
}

# unless
my $vide = 0;
unless $vide {
    say "non vide";
}

# given / when / default
my $jour = 3;
given $jour {
    when 1 { say "lundi"; }
    when 2 { say "mardi"; }
    when 3 { say "mercredi"; }
    when 4 { say "jeudi"; }
    when 5 { say "vendredi"; }
    default { say "weekend"; }
}

# Operateur ternaire
my $r = $x > 5 ?? "grand" !! "petit";
say $r;
