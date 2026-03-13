/* math.rex - Exemple REXX : operations arithmetiques, NUMERIC DIGITS */

/* Operations de base */
say '=== Operations arithmetiques ==='
say '5 + 3   =' 5 + 3
say '10 - 4  =' 10 - 4
say '6 * 7   =' 6 * 7
say '20 / 4  =' 20 / 4
say '17 % 5  =' 17 % 5
say '17 // 5 =' 17 // 5
say '2 ** 10 =' 2 ** 10

/* Variables et calculs */
say
say '=== Calculs avec variables ==='
a = 100
b = 37
say 'a =' a
say 'b =' b
say 'a + b =' a + b
say 'a - b =' a - b
say 'a * b =' a * b
say 'a / b =' a / b
say 'a % b =' a % b
say 'a // b =' a // b

/* Fonctions arithmetiques */
say
say '=== Fonctions arithmetiques ==='
say 'ABS(-42) =' abs(-42)
say 'ABS(17)  =' abs(17)
say 'SIGN(-9) =' sign(-9)
say 'SIGN(0)  =' sign(0)
say 'SIGN(5)  =' sign(5)
say 'MAX(3,7) =' max(3, 7)
say 'MIN(3,7) =' min(3, 7)
say 'TRUNC(99) =' trunc(99)

/* NUMERIC DIGITS */
say
say '=== NUMERIC DIGITS ==='
say 'DIGITS() =' digits()
numeric digits 5
say 'Apres NUMERIC DIGITS 5 :' digits()
numeric digits
say 'Apres reset :' digits()

/* NUMERIC FORM */
say
say '=== NUMERIC FORM ==='
say 'FORM() =' form()
numeric form engineering
say 'Apres ENGINEERING :' form()
numeric form scientific
say 'Retour SCIENTIFIC :' form()

say
say 'Fin du programme math.rex'
