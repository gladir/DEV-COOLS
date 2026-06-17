/* test_gaminv.sas - GAMINV : quantile d une distribution Gamma */
data _null_;
  /* GAMINV(p, shape), p en pourcentage entier */
  a = gaminv(95, 2);
  put 'GAMINV(95,2) = ' a '  (attendu: 4)';
  b = gaminv(50, 1);
  put 'GAMINV(50,1) = ' b '  (attendu: 1)';
  z = gaminv(95, 0);
  put 'GAMINV(95,0) = ' z '  (attendu: 0)';
run;
