*----------------------------------------------------------------*
* test_fixed_point.abap                                          *
*----------------------------------------------------------------*
* Demonstration de l arithmetique en virgule fixe sans FPU        *
* pour les types TYPE F (flottant logiciel, 6 decimales par       *
* defaut) et TYPE P DECIMALS n (packed decimal).                  *
* Teste aussi l operateur && de concatenation de chaines.         *
*----------------------------------------------------------------*
REPORT ztest_fixed_point.

DATA pi TYPE P DECIMALS 4 VALUE '3.14159'.
DATA r  TYPE P DECIMALS 2.
DATA f  TYPE F VALUE '1.5'.
DATA g  TYPE F.
DATA n  TYPE P DECIMALS 2 VALUE '-2.5'.
DATA a  TYPE P DECIMALS 4 VALUE '10'.
DATA b  TYPE P DECIMALS 4 VALUE '3'.
DATA q  TYPE P DECIMALS 4.
DATA msg(80).

WRITE: 'pi       =', pi, /.
r = pi + 1.
WRITE: 'pi + 1   =', r, /.
r = pi - 1.
WRITE: 'pi - 1   =', r, /.
r = pi * 2.
WRITE: 'pi * 2   =', r, /.
q = a / b.
WRITE: '10 / 3   =', q, /.
WRITE: 'f        =', f, /.
g = f + f + f.
WRITE: '3 * f    =', g, /.
g = f * f.
WRITE: 'f * f    =', g, /.
WRITE: 'n        =', n, /.
r = n + pi.
WRITE: 'n + pi   =', r, /.

msg = 'Hello' && ' ' && 'World' && '!'.
WRITE: msg, /.

WRITE: 'Fin du test virgule fixe.', /.
