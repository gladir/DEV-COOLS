/* test_runtime.sas - test TODO 24 : RUNTIME MINIMAL */
/* Teste les routines runtime de base : PUT, expressions, fonctions */
data _null_;
  a = 5;
  b = 3;
  c = a ** b;
  put 'Puissance : ' c;
  d = abs(-42);
  put 'ABS(-42) = ' d;
  x = 'HELLO';
  y = 'WORLD';
  z = x || y;
  put 'Concat : ' z;
  if x = 'HELLO' then put 'String compare OK';
  put 'Runtime OK';
run;
