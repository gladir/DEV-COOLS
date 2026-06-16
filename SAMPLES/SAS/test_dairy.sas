/* test_dairy.sas - DAIRY : derivee de la fonction AIRY */
data _null_;
  /* Backend entier : serie Airy derivee puis floor */
  a = dairy(0);
  put 'DAIRY(0) = ' a '  (attendu: -1)';
  b = dairy(1);
  put 'DAIRY(1) = ' b '  (attendu: -1)';
  c = dairy(-1);
  put 'DAIRY(-1) = ' c '  (attendu: -1)';
run;
