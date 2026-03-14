/* test_stems.rexx - Test des variables composees (TODO 19) */

/* Affectation et lecture avec indice statique */
tab.1 = "un"
tab.2 = "deux"
tab.3 = "trois"
say tab.1
say tab.2
say tab.3

/* Valeur par defaut de la tige */
def. = "zero"
say def.1
say def.99

/* Affectation avec indice dynamique */
i = 1
arr.i = "premier"
say arr.1

/* Lecture avec indice dynamique */
j = 2
tab.j = "DEUX"
say tab.2

/* Ecrasement de valeur */
tab.1 = "UN"
say tab.1

/* DROP d une tige */
drop tab.
say tab.1
