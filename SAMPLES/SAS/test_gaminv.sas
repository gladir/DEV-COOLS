/* test_gaminv.sas - GAMINV : quantile d une distribution Gamma (stub) */
data _null_;
  /* GAMINV(p, shape) */
  a = gaminv(0.95, 2);
  put 'GAMINV(0.95,2) = ' a;
  b = gaminv(0.50, 1);
  put 'GAMINV(0.50,1) = ' b;
run;
