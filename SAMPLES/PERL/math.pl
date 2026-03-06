#!/usr/bin/perl
# math.pl - Exemple PERL86 : sous-routines, arithmetique, return, recursion
# Compile : PERL86.EXE SAMPLES\PERL\math.pl math.asm

use strict;
use warnings;

sub add {
  my ($a, $b) = @_;
  return $a + $b;
}

sub sub2 {
  my ($a, $b) = @_;
  return $a - $b;
}

sub mul {
  my ($a, $b) = @_;
  return $a * $b;
}

sub divmod {
  my ($a, $b) = @_;
  return $a / $b;
}

# Factorielle recursive
sub fact {
  my ($n) = @_;
  if ($n <= 1) {
    return 1;
  }
  return $n * fact($n - 1);
}

# Fibonacci recursif
sub fib {
  my ($n) = @_;
  if ($n <= 1) {
    return $n;
  }
  return fib($n - 1) + fib($n - 2);
}

my $r1 = add(10, 20);
print "10 + 20 = ";
print $r1;
print "\n";

my $r2 = sub2(50, 8);
print "50 - 8 = ";
print $r2;
print "\n";

my $r3 = mul(6, 7);
print "6 * 7 = ";
print $r3;
print "\n";

my $r4 = divmod(100, 4);
print "100 / 4 = ";
print $r4;
print "\n";

my $f5 = fact(5);
print "5! = ";
print $f5;
print "\n";

my $f6 = fact(6);
print "6! = ";
print $f6;
print "\n";

my $fb7 = fib(7);
print "fib(7) = ";
print $fb7;
print "\n";

# Modulo
my $m = 17;
my $rem = $m - (($m / 5) * 5);
print "17 mod 5 = ";
print $rem;
print "\n";

# Valeur absolue
my $neg = 0 - 42;
my $pos = abs($neg);
print "abs(-42) = ";
print $pos;
print "\n";
