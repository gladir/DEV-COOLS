use strict;
use warnings;

my $s = "hello world";

if ($s =~ /world/) {
    print "match: trouve world\n";
} else {
    print "match: pas trouve\n";
}

if ($s !~ /xyz/) {
    print "notmatch: xyz absent\n";
} else {
    print "notmatch: xyz present\n";
}

my $t = "hello world";
$t =~ s/world/perl/;
print $t;
print "\n";
