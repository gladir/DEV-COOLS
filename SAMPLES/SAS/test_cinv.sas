/* test_cinv.sas - CINV : quantile du Chi au carre (stub) */
data _null_;
  /* CINV(0.95, 5) = quantile a 95% avec 5 deg liberte (stub=0) */
  a = cinv(95, 5);
  put 'CINV(95,5) = ' a;
  b = cinv(99, 10);
  put 'CINV(99,10) = ' b;
run;
