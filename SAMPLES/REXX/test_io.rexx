/* test_io.rexx - Test des entrees/sorties REXX */
/* TODO 12 : SAY, PULL, PARSE PULL              */

/* SAY avec chaine */
say "Hello, World!"

/* SAY avec nombre */
say 42

/* SAY avec expression arithmetique */
say 2 + 3

/* SAY avec concatenation */
say "Resultat:" || " 10"

/* SAY sans argument (ligne vide) */
say

/* SAY avec variable */
x = "Bonjour"
say x

/* Affectation et SAY */
nom = "REXX"
say "Langage:" nom
