/* test_functions.sas - Test des fonctions integrees SAS (TODO 22) */

/* ======= Fonctions numeriques ======= */

/* Test 1 : ABS - valeur absolue */
data test1;
  x = -42;
  y = abs(x);
  put y;
run;

/* Test 2 : INT - partie entiere */
data test2;
  x = 123;
  y = int(x);
  put y;
run;

/* Test 3 : SIGN - signe */
data test3;
  a = sign(-10);
  b = sign(0);
  c = sign(5);
  put a b c;
run;

/* Test 4 : MOD - modulo */
data test4;
  x = mod(17, 5);
  put x;
run;

/* Test 5 : MIN et MAX */
data test5;
  a = min(10, 20);
  b = max(10, 20);
  put a b;
run;

/* Test 6 : SUM - somme */
data test6;
  total = sum(1, 2, 3, 4, 5);
  put total;
run;

/* Test 7 : ROUND, CEIL, FLOOR */
data test7;
  x = round(27);
  y = ceil(15);
  z = floor(15);
  put x y z;
run;

/* ======= Fonctions caracteres ======= */

/* Test 8 : LENGTH - longueur */
data test8;
  x = 'Hello World';
  n = length(x);
  put n;
run;

/* Test 9 : UPCASE / LOWCASE */
data test9;
  x = 'Hello';
  u = upcase(x);
  l = lowcase(x);
  put u l;
run;

/* Test 10 : TRIM - espaces de fin */
data test10;
  x = 'Hello   ';
  y = trim(x);
  put y;
run;

/* Test 11 : LEFT - espaces de debut */
data test11;
  x = '   World';
  y = left(x);
  put y;
run;

/* Test 12 : SUBSTR - sous-chaine */
data test12;
  x = 'Bonjour le monde';
  y = substr(x, 1, 7);
  put y;
run;

/* Test 13 : SUBSTR sans longueur */
data test13;
  x = 'Hello World';
  y = substr(x, 7);
  put y;
run;

/* Test 14 : INDEX - recherche sous-chaine */
data test14;
  x = 'Hello World';
  pos = index(x, 'World');
  put pos;
run;

/* Test 15 : COMPRESS - supprimer espaces */
data test15;
  x = 'A B C D';
  y = compress(x);
  put y;
run;

/* Test 16 : COMPRESS avec 2e argument */
data test16;
  x = 'Hello123World';
  y = compress(x, '0123456789');
  put y;
run;

/* Test 17 : CAT - concatenation */
data test17;
  a = 'Bon';
  b = 'jour';
  c = cat(a, b);
  put c;
run;

/* Test 18 : PUT - conversion num -> char */
data test18;
  n = 42;
  s = put(n);
  put s;
run;

/* ======= Fonctions de date ======= */

/* Test 19 : TODAY - date courante */
data test19;
  d = today();
  put d;
run;

/* Test 20 : MDY - construire une date */
data test20;
  d = mdy(3, 11, 2026);
  put d;
run;

/* Test 21 : YEAR / MONTH / DAY - extraire composantes */
data test21;
  d = mdy(7, 4, 1976);
  y = year(d);
  m = month(d);
  j = day(d);
  put y m j;
run;

/* Test 22 : Combinaison fonctions */
data test22;
  nom = '  Alice  ';
  nom_clean = upcase(trim(left(nom)));
  put nom_clean;
run;

/* Test 23 : SQRT / LOG / EXP stubs */
data test23;
  a = sqrt(16);
  b = log(256);
  c = exp(0);
  put a b c;
run;

/* Test 24 : RIGHT - alignement a droite */
data test24;
  x = 'Hello';
  y = right(x);
  put y;
run;
