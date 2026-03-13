/* funcs.rex - Exemple REXX : CALL, RETURN, PROCEDURE EXPOSE, recursion */

/* Appel simple avec CALL */
say '=== CALL simple ==='
call saluer
say result

/* Appel avec RETURN valeur */
say
say '=== Fonction avec RETURN ==='
x = doubler("7")
say 'doubler(7) =' x

/* PROCEDURE avec argument */
say
say '=== PROCEDURE avec argument ==='
say 'carre(5) =' carre("5")
say 'carre(12) =' carre("12")

/* PROCEDURE EXPOSE */
say
say '=== PROCEDURE EXPOSE ==='
total = "0"
call ajouter
call ajouter
call ajouter
say 'Total apres 3 appels :' total

/* CALL avec PARSE ARG */
say
say '=== CALL avec arguments ==='
say 'additionner(3,4) =' additionner("3", "4")
say 'additionner(10,20) =' additionner("10", "20")

/* Recursion simple */
say
say '=== Recursion ==='
say 'factorielle(5) =' factorielle("5")
say 'factorielle(1) =' factorielle("1")

say
say 'Fin du programme funcs.rex'
exit

/* --- Procedures et fonctions internes --- */

saluer:
  return 'Bonjour depuis une procedure!'

doubler:
  procedure
  parse arg n
  return n * 2

carre:
  procedure
  parse arg v
  return v * v

ajouter:
  procedure expose total
  total = total + 1
  return

additionner:
  procedure
  parse arg a, b
  return a + b

factorielle:
  procedure
  parse arg n
  if n <= 1 then return 1
  return n * factorielle(n - 1)
