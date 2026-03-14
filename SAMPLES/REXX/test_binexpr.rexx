/* test_binexpr.rexx - Test des expressions binaires et concatenation */
/* TODO 11 : expressions binaires, concatenation, comparaisons        */

/* Arithmetique de base */
say 2 + 3
say 10 - 4
say 3 * 5
say 20 / 4
say 7 % 3
say 7 // 3
say 2 ** 5

/* Concatenation explicite */
say "Hello" || "World"
say "abc" || "def"

/* Concatenation implicite (espace) */
say "Hello" "World"

/* Comparaisons normales */
say "abc" = "abc"
say "abc" \= "def"
say "b" > "a"
say "a" < "b"

/* Comparaisons strictes */
say "abc" == "abc"
say "abc" \== "def"

/* Logique */
say 1 & 1
say 1 & 0
say 0 | 1
say 0 | 0
say 1 && 0
say 1 && 1

/* NOT logique */
say \ 0
say \ 1
