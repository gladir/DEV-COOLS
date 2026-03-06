#!/usr/bin/perl
# arrays.pl - Exemple PERL86 : tableaux, push/pop/shift, foreach, acces indexe
# Compile : PERL86.EXE SAMPLES\PERL\arrays.pl arrays.asm

use strict;
use warnings;

# Declaration et initialisation
my @nums = (10, 20, 30, 40, 50);

# Taille du tableau
my $len = scalar(@nums);
print "taille=";
print $len;
print "\n";

# Acces par index
my $first = $nums[0];
print "nums[0]=";
print $first;
print "\n";

my $third = $nums[2];
print "nums[2]=";
print $third;
print "\n";

# Affectation d'un element
$nums[1] = 99;
print "nums[1] apres=";
print $nums[1];
print "\n";

# push
push @nums, 60;
my $newlen = scalar(@nums);
print "apres push taille=";
print $newlen;
print "\n";

# foreach sur tableau
foreach my $v (1, 2, 3, 4, 5) {
  print $v;
  print " ";
}
print "\n";

# foreach sur plage
foreach my $v (1, 2, 3) {
  my $sq = $v * $v;
  print "carre ";
  print $v;
  print "=";
  print $sq;
  print "\n";
}

# Tableau de chaines
my @mots = ("alfa", "bravo", "charlie");
my $m0 = $mots[0];
print $m0;
print "\n";
my $m1 = $mots[1];
print $m1;
print "\n";

# Tableau vide puis remplissage
my @pile = (0);
push @pile, 100;
push @pile, 200;
push @pile, 300;
print "pile[1]=";
print $pile[1];
print "\n";
print "pile[2]=";
print $pile[2];
print "\n";
