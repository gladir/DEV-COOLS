/* test_cosh.sas - COSH : cosinus hyperbolique (stub) */
data _null_;
  /* COSH(0) = 1 (stub retourne 0) */
  a = cosh(0);
  put 'COSH(0) = ' a;
  b = cosh(1);
  put 'COSH(1) = ' b;
run;
