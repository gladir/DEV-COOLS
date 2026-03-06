#!/usr/bin/perl
# control.pl - Exemple PERL86 : if/elsif/else, while, foreach
# Compile : PERL86.EXE SAMPLES\PERL\control.pl control.asm

use strict;
use warnings;

# --- if / elsif / else ---
my $n = 10;

if ($n > 15) {
  print "grand\n";
} elsif ($n > 5) {
  print "moyen\n";
} elsif ($n == 5) {
  print "egal cinq\n";
} else {
  print "petit\n";
}

# --- if simple avec else ---
my $flag = 1;
if ($flag == 0) {
  print "faux\n";
} else {
  print "vrai\n";
}

# --- while simple ---
my $i = 1;
while ($i <= 5) {
  print $i;
  print "\n";
  $i = $i + 1;
}

# --- while decroissant ---
my $cnt = 10;
while ($cnt > 0) {
  $cnt = $cnt - 3;
}
print "cnt=";
print $cnt;
print "\n";

# --- foreach sur liste litterale ---
foreach my $elem (10, 20, 30) {
  print "elem=";
  print $elem;
  print "\n";
}

# --- conditions imbriquees ---
my $a = 5;
my $b = 10;
if ($a > 0) {
  if ($b > 0) {
    print "tous deux positifs\n";
  } else {
    print "b negatif\n";
  }
}
if ($a > 100) {
  print "a tres grand\n";
} else {
  print "a raisonnable\n";
}
