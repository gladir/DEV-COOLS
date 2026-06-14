/* test_dairy.sas - DAIRY : derivee de la fonction AIRY (stub) */
data _null_;
  /* DAIRY(0) = -0.25881... (stub retourne 0) */
  a = dairy(0);
  put 'DAIRY(0) = ' a;
  b = dairy(1);
  put 'DAIRY(1) = ' b;
  c = dairy(-1);
  put 'DAIRY(-1) = ' c;
run;
