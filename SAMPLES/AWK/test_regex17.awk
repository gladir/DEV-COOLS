# test_regex17.awk - Tests pour TODO 17 (expressions regulieres ~ !~)
# Compile avec : AWKCW32 test_regex17.awk -o test_regex17.asm
# 15 cas de test pour les expressions regulieres

BEGIN {
    print "=== Test TODO 17 : Expressions regulieres ==="

    # --- Cas 1 : match simple avec ~ ---
    m1 = ("hello" ~ /ell/)
    print "Cas 1: match ~ /ell/ = " m1

    # --- Cas 2 : non-match avec !~ ---
    m2 = ("hello" !~ /xyz/)
    print "Cas 2: notmatch !~ /xyz/ = " m2

    # --- Cas 3 : match debut de chaine ---
    m3 = ("abcdef" ~ /^abc/)
    print "Cas 3: match ~ /^abc/ = " m3

    # --- Cas 4 : match fin de chaine ---
    m4 = ("abcdef" ~ /def$/)
    print "Cas 4: match ~ /def$/ = " m4

    # --- Cas 5 : match avec point (tout caractere) ---
    m5 = ("abc" ~ /a.c/)
    print "Cas 5: match ~ /a.c/ = " m5

    # --- Cas 6 : match avec etoile (repetition) ---
    m6 = ("aabbb" ~ /ab*/)
    print "Cas 6: match ~ /ab*/ = " m6

    # --- Cas 7 : non-match qui echoue (retourne 0) ---
    m7 = ("hello" ~ /world/)
    print "Cas 7: match ~ /world/ = " m7

    # --- Cas 8 : !~ qui echoue (retourne 0 car match) ---
    m8 = ("hello" !~ /hello/)
    print "Cas 8: notmatch !~ /hello/ = " m8

    # --- Cas 9 : match avec variable ---
    s = "test string"
    m9 = (s ~ /test/)
    print "Cas 9: var ~ /test/ = " m9

    # --- Cas 10 : match avec classe de caracteres ---
    m10 = ("abc123" ~ /[0-9]/)
    print "Cas 10: match ~ /[0-9]/ = " m10

    # --- Cas 11 : match dans un if ---
    if ("foo bar" ~ /bar/) {
        print "Cas 11: if match = OK"
    }

    # --- Cas 12 : !~ dans un if ---
    if ("foo" !~ /baz/) {
        print "Cas 12: if !~ = OK"
    }

    # --- Cas 13 : match avec alternation ---
    m13 = ("cat" ~ /cat|dog/)
    print "Cas 13: match ~ /cat|dog/ = " m13

    # --- Cas 14 : match chaine vide ---
    m14 = ("" ~ /.*/)
    print "Cas 14: match vide ~ /.*/ = " m14

    # --- Cas 15 : match avec caracteres speciaux ---
    m15 = ("a+b" ~ /a\+b/)
    print "Cas 15: match ~ /a\\+b/ = " m15

    print "=== Fin tests TODO 17 ==="
}
