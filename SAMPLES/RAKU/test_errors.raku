# test_errors.raku - Test du TODO 22 : gestion des erreurs

# Test 1 : warn simple
warn "ceci est un avertissement";

# Test 2 : try/CATCH avec die
try {
    say "avant die";
    die "erreur fatale";
    CATCH {
        default {
            say "exception attrapee";
        }
    }
}
say "apres try";

# Test 3 : fail (equivalent a die simplifie)
try {
    fail "echec paresseux";
    CATCH {
        default {
            say "fail attrape";
        }
    }
}

# Test 4 : warn ne leve pas d exception
say "avant warn";
warn "attention";
say "apres warn";
