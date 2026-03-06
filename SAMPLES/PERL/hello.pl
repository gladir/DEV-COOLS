#!/usr/bin/perl
# hello.pl - Exemple PERL86 : print, scalaires, concatenation
# Compile : PERL86.EXE SAMPLES\PERL\hello.pl hello.asm

use strict;
use warnings;

my $name = "PERL86";
my $vers = "1.0";
my $msg  = "Compilateur Perl -> 8086";

print "Bonjour de " . $name . " v" . $vers . "\n";
print $msg . "\n";

# Arithmetique simple
my $a = 10;
my $b = 32;
my $c = $a + $b;
print "10 + 32 = ";
print $c;
print "\n";

# Concatenation avec .
my $s1 = "Hello";
my $s2 = " World";
my $s3 = $s1 . $s2;
print $s3;
print "\n";

# Concatenation composee .=
my $full = "Perl";
$full .= " 86";
$full .= " rocks";
print $full;
print "\n";

# Repetition x
my $line = "-" x 20;
print $line;
print "\n";
