/* test_numeric.rexx - Test TODO 20 ARITHMETIQUE ET NUMERIC DIGITS */

/* Test NUMERIC DIGITS par defaut */
d = DIGITS()
SAY "DIGITS par defaut :" d

/* Test NUMERIC FORM par defaut */
f = FORM()
SAY "FORM par defaut :" f

/* Test NUMERIC FUZZ par defaut */
z = FUZZ()
SAY "FUZZ par defaut :" z

/* Test changement de NUMERIC DIGITS */
NUMERIC DIGITS 5
d2 = DIGITS()
SAY "DIGITS apres changement :" d2

/* Test changement de NUMERIC FORM */
NUMERIC FORM ENGINEERING
f2 = FORM()
SAY "FORM apres changement :" f2

/* Test retour a SCIENTIFIC */
NUMERIC FORM SCIENTIFIC
f3 = FORM()
SAY "FORM retour SCIENTIFIC :" f3

/* Test changement de NUMERIC FUZZ */
NUMERIC FUZZ 2
z2 = FUZZ()
SAY "FUZZ apres changement :" z2

/* Test reset NUMERIC DIGITS sans argument */
NUMERIC DIGITS
d3 = DIGITS()
SAY "DIGITS apres reset :" d3

/* Test reset NUMERIC FUZZ sans argument */
NUMERIC FUZZ
z3 = FUZZ()
SAY "FUZZ apres reset :" z3

/* Test operations arithmetiques de base */
a = 10 + 5
SAY "10 + 5 =" a
b = 10 - 3
SAY "10 - 3 =" b
c = 6 * 7
SAY "6 * 7 =" c
d = 100 / 4
SAY "100 / 4 =" d
e = 17 // 5
SAY "17 // 5 =" e
f = 2 ** 8
SAY "2 ** 8 =" f

/* Test division entiere */
g = 17 % 5
SAY "17 % 5 =" g

SAY "Test NUMERIC termine."
