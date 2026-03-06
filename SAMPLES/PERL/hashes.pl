#!/usr/bin/perl
# hashes.pl - Exemple PERL86 : hashes, acces, exists, delete
# Compile : PERL86.EXE SAMPLES\PERL\hashes.pl hashes.asm

use strict;
use warnings;

# Declaration et initialisation
my %scores = ("alice" => 95, "bob" => 78, "charlie" => 88);

# Acces par cle constante
my $s1 = $scores{"alice"};
print "alice=";
print $s1;
print "\n";

my $s2 = $scores{"bob"};
print "bob=";
print $s2;
print "\n";

my $s3 = $scores{"charlie"};
print "charlie=";
print $s3;
print "\n";

# Affectation d'une nouvelle cle
$scores{"diana"} = 91;
my $s4 = $scores{"diana"};
print "diana=";
print $s4;
print "\n";

# exists
if (exists $scores{"alice"}) {
  print "alice existe\n";
}

if (exists $scores{"zoe"}) {
  print "zoe existe\n";
} else {
  print "zoe absent\n";
}

# Modification d'une valeur existante
$scores{"bob"} = 85;
my $bob2 = $scores{"bob"};
print "bob update=";
print $bob2;
print "\n";

# Hash de chaines
my %pays = ("fr" => "France", "de" => "Allemagne", "es" => "Espagne");

my $p1 = $pays{"fr"};
print $p1;
print "\n";

my $p2 = $pays{"de"};
print $p2;
print "\n";

# Test exists / valeur zero
my %compteurs = ("a" => 1, "b" => 0, "c" => 3);
if (exists $compteurs{"b"}) {
  print "b existe (valeur=0)\n";
}

delete $compteurs{"a"};
if (exists $compteurs{"a"}) {
  print "a encore la\n";
} else {
  print "a supprime\n";
}
