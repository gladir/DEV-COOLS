/* test_finv.sas - FINV : inverse de la distribution F (stub) */
data _null_;
  /* FINV(p, ndf, ddf) */
  a = finv(0.95, 2, 10);
  put 'FINV(0.95,2,10) = ' a;
  b = finv(0.99, 5, 20);
  put 'FINV(0.99,5,20) = ' b;
run;
