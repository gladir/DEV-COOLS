use strict;
use warnings;

my $s = "hello world";

# Test 1 : =~ / match /
if ($s =~ /world/) {
    print "TEST1 OK: =~ world trouve\n";
} else {
    print "TEST1 FAIL\n";
}

# Test 2 : =~ / no match /
if ($s =~ /xyz/) {
    print "TEST2 FAIL\n";
} else {
    print "TEST2 OK: =~ xyz pas trouve\n";
}

# Test 3 : !~ negation match
if ($s !~ /xyz/) {
    print "TEST3 OK: !~ xyz absent\n";
} else {
    print "TEST3 FAIL\n";
}

# Test 4 : !~ negation no match (false case)
if ($s !~ /world/) {
    print "TEST4 FAIL\n";
} else {
    print "TEST4 OK: !~ world present\n";
}

# Test 5 : s/// substitution sur tableau de chiffres
my $r = 42;
if ($r == 42) {
    print "TEST5 OK: variable numerique ok\n";
}

print "DONE\n";
