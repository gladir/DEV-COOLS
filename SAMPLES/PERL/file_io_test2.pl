#!/usr/bin/perl
# Test TODO 23 - mode append et eof

open(my $fa, '>>', 'append_test.txt');
print $fa, "Texte appende\n";
close($fa);

open(my $fc, '<', 'append_test.txt');
my $e1 = eof($fc);
my $line = readline($fc);
my $e2 = eof($fc);
close($fc);

print STDOUT "eof avant lecture: ";
print STDOUT $e1;
print STDOUT "eof apres lecture: ";
print STDOUT $e2;
