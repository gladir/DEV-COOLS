# test_loops.raku - Test des boucles (TODO 14)
# Verifie le code genere pour :
#   - while cond { stmts }
#   - until cond { stmts }
#   - loop { stmts } (boucle infinie avec last)
#   - loop (init; cond; incr) { stmts }
#   - repeat { stmts } while cond;
#   - repeat { stmts } until cond;
#   - for RANGE -> $var { stmts }
#   - last / next / redo

# ---- Test 1 : while simple ----
my $i = 1;
while $i <= 5 {
    say $i;
    $i = $i + 1;
}

# ---- Test 2 : until simple ----
my $j = 10;
until $j < 7 {
    say $j;
    $j = $j - 1;
}

# ---- Test 3 : loop infini avec last ----
my $k = 0;
loop {
    $k = $k + 1;
    if $k > 3 {
        last;
    }
    say $k;
}

# ---- Test 4 : loop C-style ----
loop (my $x = 0; $x < 4; $x = $x + 1) {
    say $x;
}

# ---- Test 5 : repeat while ----
my $m = 1;
repeat {
    say $m;
    $m = $m + 1;
} while $m <= 3;

# ---- Test 6 : repeat until ----
my $n = 10;
repeat {
    say $n;
    $n = $n - 1;
} until $n < 8;

# ---- Test 7 : for range ----
for 1..5 -> $r {
    say $r;
}

# ---- Test 8 : next (skip iteration) ----
my $s = 0;
while $s < 5 {
    $s = $s + 1;
    if $s == 3 {
        next;
    }
    say $s;
}

say "done";
