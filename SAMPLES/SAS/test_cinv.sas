/* test_cinv.sas - CINV : quantile du Chi au carre */
data _null_;
  /* Backend entier : approximation df + z*sqrt(2*df) */
  a = cinv(95, 5);
  put 'CINV(95,5) = ' a '  (attendu: 11)';
  b = cinv(99, 10);
  put 'CINV(99,10) = ' b '  (attendu: 22)';
run;
