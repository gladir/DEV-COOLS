/* stems.rex - Exemple REXX : variables composees tab.i, DROP, valeur defaut */

/* Affectation avec indices statiques */
say '=== Indices statiques ==='
fruit.1 = 'pomme'
fruit.2 = 'banane'
fruit.3 = 'cerise'
say 'fruit.1 =' fruit.1
say 'fruit.2 =' fruit.2
say 'fruit.3 =' fruit.3

/* Valeur par defaut de la tige */
say
say '=== Valeur par defaut ==='
prix. = '0'
say 'prix.99 (defaut) =' prix.99
prix.1 = '10'
say 'prix.1 =' prix.1
say 'prix.2 (defaut) =' prix.2

/* Affectation avec indice dynamique */
say
say '=== Indices dynamiques ==='
i = 1
tab.i = 'premier'
i = 2
tab.i = 'deuxieme'
i = 3
tab.i = 'troisieme'
say 'tab.1 =' tab.1
say 'tab.2 =' tab.2
say 'tab.3 =' tab.3

/* Lecture avec indice dynamique */
say
say '=== Lecture dynamique ==='
j = 2
say 'tab.' || j '=' tab.j

/* Ecrasement de valeur */
say
say '=== Ecrasement ==='
fruit.1 = 'POMME'
say 'fruit.1 ecrase =' fruit.1

/* DROP (reinitialisation de la tige) */
say
say '=== DROP ==='
drop fruit.
say 'fruit.1 apres DROP =' fruit.1

say
say 'Fin du programme stems.rex'
