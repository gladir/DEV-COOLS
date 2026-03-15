# test_cond.raku - Test TODO 13 : CONDITIONNELLES (if/elsif/else, unless, given/when)
# Compile : RAKU86 test_cond.raku test_cond.asm

# --- if simple ---
my $x = 10;
if $x > 0 {
    say "positif";
}

# --- if / else ---
my $y = -5;
if $y > 0 {
    say "y positif";
} else {
    say "y negatif ou nul";
}

# --- if / elsif / else ---
my $z = 0;
if $z > 0 {
    say "z positif";
} elsif $z == 0 {
    say "z nul";
} else {
    say "z negatif";
}

# --- if / elsif / elsif / else ---
my $note = 75;
if $note > 90 {
    say "excellent";
} elsif $note > 70 {
    say "bien";
} elsif $note > 50 {
    say "moyen";
} else {
    say "insuffisant";
}

# --- unless simple ---
my $flag = 0;
unless $flag {
    say "flag est faux";
}

# --- unless / else ---
my $ok = 1;
unless $ok {
    say "pas ok";
} else {
    say "ok";
}

# --- given / when / default ---
my $val = 2;
given $val {
    when 1 {
        say "un";
    }
    when 2 {
        say "deux";
    }
    when 3 {
        say "trois";
    }
    default {
        say "autre";
    }
}

# --- given avec default seulement ---
my $w = 99;
given $w {
    when 1 {
        say "un";
    }
    default {
        say "pas un";
    }
}
