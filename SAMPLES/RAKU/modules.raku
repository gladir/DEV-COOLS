# modules.raku - module, use, is export

# Pragma de version (ignore)
use v6;

# Declaration d un module
module MathUtils {
    sub double($n) is export {
        return $n * 2;
    }

    sub triple($n) is export {
        return $n * 3;
    }
}

# Sub exportee hors module
sub helper() is export {
    say "helper";
}

# Utilisation de need (chargement sans import)
need File::Path;

# Appel des fonctions
say double(21);
say triple(14);
helper();
