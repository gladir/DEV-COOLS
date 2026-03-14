# errors.raku - try, CATCH, die, fail, warn

# warn : avertissement sur STDERR
warn "ceci est un avertissement";

# try / CATCH avec die
try {
    say "avant die";
    die "erreur fatale";
    CATCH {
        default {
            say "exception attrapee";
        }
    }
}

# try / CATCH avec fail
try {
    say "avant fail";
    fail "echec";
    CATCH {
        default {
            say "fail attrape";
        }
    }
}

# Code apres les exceptions
say "programme continue";

# try sans exception
try {
    my $x = 10;
    say $x;
    CATCH {
        default {
            say "pas d erreur";
        }
    }
}

say "fin";
