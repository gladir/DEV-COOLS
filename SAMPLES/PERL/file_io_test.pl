#!/usr/bin/perl
# Test TODO 23 - I/O Fichiers basique

# Ecriture dans un fichier
open(my $fw, '>', 'test_out.txt');
print $fw, "Ligne 1\n";
print $fw, "Ligne 2\n";
close($fw);

# Lecture depuis le fichier
open(my $fr, '<', 'test_out.txt');
my $line1 = readline($fr);
close($fr);

print STDOUT "Lu: ";
print STDOUT $line1;
