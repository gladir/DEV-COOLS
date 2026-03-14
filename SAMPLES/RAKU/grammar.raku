# grammar.raku - grammar, token, rule, parse, actions

# Grammar pour des entiers
grammar IntParser {
    token digit { <[0..9]> }
    token sign  { '+' | '-' }
    rule  TOP   { <sign>? <digit>+ }
}

# Test de parsing
my $r1 = IntParser.parse("42");
say $r1;

my $r2 = IntParser.parse("-7");
say $r2;

# Grammar pour identifiants
grammar IdentParser {
    token alpha { <[a..z]> }
    token alnum { <[a..z]> | <[0..9]> }
    rule  TOP   { <alpha> <alnum>* }
}

my $r3 = IdentParser.parse("hello");
say $r3;

# Grammar avec alternation
grammar YesNo {
    token TOP { 'yes' | 'no' }
}

my $r4 = YesNo.parse("yes");
say $r4;

my $r5 = YesNo.parse("no");
say $r5;
