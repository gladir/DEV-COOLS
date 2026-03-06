#!/usr/bin/perl
# regex.pl - Exemple PERL86 : expressions regulieres basiques (=~ !~ s///)
# Compile : PERL86.EXE SAMPLES\PERL\regex.pl regex.asm

use strict;
use warnings;

# Correspondance simple =~
my $str = "Bonjour Monde";

if ($str =~ /Bonjour/) {
  print "trouve: Bonjour\n";
} else {
  print "absent: Bonjour\n";
}

if ($str =~ /Monde/) {
  print "trouve: Monde\n";
}

# Negation !~
if ($str !~ /Adieu/) {
  print "absent: Adieu\n";
}

# Recherche en chaine
my $email = "user@example.com";
if ($email =~ /example/) {
  print "domaine example detecte\n";
}

# Substitution s///
my $msg = "Hello World";
$msg =~ s/World/Perl/;
print $msg;
print "\n";

# Plusieurs substitutions successives
my $code = "foo bar foo";
$code =~ s/foo/baz/;
print $code;
print "\n";

# Test sur variable modifiee
my $url = "http://www.example.com";
if ($url =~ /http/) {
  print "protocole http\n";
}
if ($url !~ /https/) {
  print "pas https\n";
}

# Combinaison : test puis substitution
my $nom = "Jean Dupont";
if ($nom =~ /Dupont/) {
  $nom =~ s/Dupont/Martin/;
  print $nom;
  print "\n";
}

# Pattern absent
my $vide = "rien ici";
if ($vide =~ /PERL86/) {
  print "trouve PERL86\n";
} else {
  print "PERL86 absent\n";
}
