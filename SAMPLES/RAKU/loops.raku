# loops.raku - for, while, until, loop, last/next/redo

# while
my $i = 1;
while $i <= 5 {
    say $i;
    $i = $i + 1;
}

# until
my $j = 10;
until $j < 7 {
    say $j;
    $j = $j - 1;
}

# loop C-style
loop (my $k = 0; $k < 4; $k = $k + 1) {
    say $k;
}

# loop infini avec last
my $m = 0;
loop {
    $m = $m + 1;
    if $m > 3 {
        last;
    }
    say $m;
}

# for avec range
for 1..5 -> $n {
    say $n;
}

# next (sauter une iteration)
for 1..6 -> $p {
    if $p == 3 {
        next;
    }
    say $p;
}

# repeat while
my $q = 1;
repeat {
    say $q;
    $q = $q + 1;
} while $q <= 3;
