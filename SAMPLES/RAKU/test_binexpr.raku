# test_binexpr.raku - Test des expressions binaires (TODO 11)

# Ce fichier teste que le compilateur gere correctement :
#   - Arithmetique entiere : + - * / div mod %%
#   - Puissance : **
#   - Concatenation : ~
#   - Repetition : x
#   - Comparaisons numeriques : == != < <= > >= <=>
#   - Comparaisons de chaines : eq ne lt le gt ge leg cmp
#   - Logiques court-circuit : && || //
#   - Ternaire : ?? !!
#   - Smart match : ~~
#   - Basse precedence : and or xor

# Arithmetique entiere
my $a = 10 + 5;
my $b = 10 - 3;
my $c = 4 * 7;
my $d = 20 / 3;
my $e = 17 div 5;
my $f = 17 mod 5;
my $g = 10 %% 5;
my $h = 10 %% 3;

# Puissance
my $p = 2 ** 8;
my $p2 = 3 ** 3;

# Concatenation de chaines
my $s1 = "Hello" ~ " " ~ "World";
my $s2 = "abc" ~ "def";

# Repetition de chaines
my $r1 = "ab" x 3;
my $r2 = "-" x 10;

# Comparaisons numeriques
my $eq = 5 == 5;
my $ne = 5 != 3;
my $lt = 3 < 5;
my $le = 5 <= 5;
my $gt = 7 > 3;
my $ge = 5 >= 5;
my $tw = 1 <=> 2;

# Comparaisons de chaines
my $seq = "abc" eq "abc";
my $sne = "abc" ne "def";
my $slt = "abc" lt "def";
my $sle = "abc" le "abc";
my $sgt = "def" gt "abc";
my $sge = "abc" ge "abc";
my $sleg = "abc" leg "def";
my $scmp = "xyz" cmp "abc";

# Logiques court-circuit
my $and1 = 1 && 2;
my $and2 = 0 && 5;
my $or1 = 0 || 42;
my $or2 = 7 || 0;
my $def = Nil // 99;

# Ternaire
my $t1 = True ?? 1 !! 0;
my $t2 = False ?? 1 !! 0;

# Smart match
my $sm = 42 ~~ 42;

# Basse precedence
my $lo1 = True and False;
my $lo2 = False or True;
my $lo3 = True xor False;

# Expressions composees avec precedence
my $expr1 = 2 + 3 * 4;
my $expr2 = (2 + 3) * 4;
my $expr3 = 10 - 2 - 3;
my $expr4 = 2 ** 3 + 1;
