/* test_finv.sas - FINV : inverse de la distribution F */
data _null_;
  /* FINV(p, ndf, ddf), p en pourcentage entier */
  a = finv(95, 2, 10);
  put 'FINV(95,2,10) = ' a '  (attendu: 3)';
  b = finv(99, 5, 20);
  put 'FINV(99,5,20) = ' b '  (attendu: 4)';
  z = finv(95, 0, 20);
  put 'FINV(95,0,20) = ' z '  (attendu: 0)';
run;
