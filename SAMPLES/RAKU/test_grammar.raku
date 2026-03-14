# test_grammar.raku - TODO 21 test: grammars and regex

# Grammar simple pour parser des identifiants
grammar Ident {
    token letter { <[a..z]> }
    token digit { <[0..9]> }
    token start { <letter> }
    rule TOP { <start> }
}

# Grammar pour parser un nombre entier
grammar Number {
    token digit { <[0..9]> }
    token TOP { <digit> }
}

# Test de Grammar.parse
my $r1 = Ident.parse("hello");
say $r1;

my $r2 = Number.parse("42");
say $r2;

# Grammar avec litteral
grammar Greeting {
    token TOP { 'hi' }
}

my $r3 = Greeting.parse("hi");
say $r3;

# Grammar avec alternation
grammar YesNo {
    token TOP { 'yes' | 'no' }
}

my $r4 = YesNo.parse("yes");
say $r4;

say "done";
