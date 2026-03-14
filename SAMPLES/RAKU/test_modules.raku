# test_modules.raku - Test TODO 23 : Modules et use

# Pragma de version (ignore)
use v6;

# Module avec declarations
module Greetings {
    sub hello() is export {
        say "Hello from module!";
    }

    sub goodbye() {
        say "Goodbye!";
    }
}

# Import de module (stub avec avertissement)
use Test;

# Need (chargement sans import)
need File::Path;

# Nom qualifie Module::Ident
my $x = 42;
say $x;

# Sub exportee
sub exported_fn() is export {
    say "I am exported";
}

exported_fn();
