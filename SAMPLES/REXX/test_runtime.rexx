/* test_runtime.rexx - Tests TODO 24 : RUNTIME MINIMAL              */
/* Verifie les fonctions de base du runtime : print, concat, strcmp, */
/* numtostr, strtonum, upper, abs, max, min, strlen, copy.           */

/* Test SAY (utilise _RXRT_PRINT et _RXRT_PRINTLN) */
say 'Test RXRT_PRINT/PRINTLN:'
say 'Hello runtime!'

/* Test concatenation (_RXRT_CONCAT) */
say 'Test RXRT_CONCAT:'
a = 'Hello'
b = ' World'
say a || b

/* Test conversion numerique (_RXRT_NUMTOSTR / _RXRT_STRTONUM) */
say 'Test RXRT_NUMTOSTR/STRTONUM:'
x = 42
say 'Nombre:' x
y = -17
say 'Negatif:' y

/* Test UPPER (_RXRT_UPPER) */
say 'Test RXRT_UPPER:'
mot = 'bonjour'
upper mot
say 'Apres UPPER:' mot

/* Test comparaison (_RXRT_STRCMP) */
say 'Test RXRT_STRCMP:'
if 'abc' = 'abc' then
  say 'abc = abc : OK'
if 'abc' \= 'def' then
  say 'abc \= def : OK'

/* Test comparaison stricte (_RXRT_STRCMPS) */
say 'Test RXRT_STRCMPS:'
if 'hello' == 'hello' then
  say 'Strict equal : OK'
if 'hello' \== 'hello ' then
  say 'Strict not equal with space : OK'

/* Test arithmetique de base (utilise _RXRT_ABS, _RXRT_MAX, _RXRT_MIN) */
say 'Test arithmetique:'
say 'ABS(-5):' abs(-5)
say 'MAX(3,7):' max(3, 7)
say 'MIN(3,7):' min(3, 7)
say 'ABS(10):' abs(10)
say 'MAX(-2,5):' max(-2, 5)
say 'MIN(-2,5):' min(-2, 5)

/* Test expressions numeriques */
say 'Test expressions:'
say '3 + 4 =' 3 + 4
say '10 - 3 =' 10 - 3
say '6 * 7 =' 6 * 7
say '20 / 4 =' 20 / 4

/* Test STRLEN (implicite via LENGTH) */
say 'Test STRLEN/LENGTH:'
say 'LENGTH("Hello"):' length('Hello')
say 'LENGTH(""):' length('')

/* Test variables et copie */
say 'Test copie de variables:'
orig = 'Valeur originale'
copie = orig
say 'Original:' orig
say 'Copie:' copie

say 'Tous les tests runtime passes!'
