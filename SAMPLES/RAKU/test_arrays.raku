# test_arrays.raku - Test tableaux et listes (TODO 15)
# Verifie le code genere pour :
#   - my @arr = (1, 2, 3) : allocation heap, pointeur en [BP-n]
#   - @arr[0], @arr[1], @arr[2] : acces indexe
#   - @arr.elems : nombre d elements
#   - @arr.push($x) : ajout en fin
#   - @arr.pop : retrait en fin
#   - @arr.reverse : inversion
#   - @arr.sort : tri insertion
#   - @arr.join(",") : concatenation avec separateur

# ---- Test 1 : declaration et acces indexe ----
my @arr = (10, 20, 30);
say @arr[0];
say @arr[1];
say @arr[2];

# ---- Test 2 : .elems ----
my $n = @arr.elems;
say $n;

# ---- Test 3 : .push ----
@arr.push(40);
say @arr.elems;

# ---- Test 4 : .pop ----
my $v = @arr.pop;
say $v;

# ---- Test 5 : .reverse ----
@arr.reverse;
say @arr[0];

# ---- Test 6 : .sort ----
@arr.sort;
say @arr[0];

# ---- Test 7 : .join ----
my $s = @arr.join(",");
say $s;
