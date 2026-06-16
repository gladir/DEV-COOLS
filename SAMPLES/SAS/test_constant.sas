/* test_constant.sas - CONSTANT : constante mathematique */
data _null_;
  /* Backend entier : floor des constantes principales */
  e = constant(0);
  put 'CONSTANT(0/E) = ' e '  (attendu: 2)';
  pi = constant(1);
  put 'CONSTANT(1/PI) = ' pi '  (attendu: 3)';
  s2 = constant('SQRT2');
  put 'CONSTANT(SQRT2) = ' s2 '  (attendu: 1)';
run;
