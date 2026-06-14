/* test_dif.sas - DIF : difference avec le lag (stub) */
data _null_;
  x = 10;
  /* DIF(x, 1) = x - LAG1(x) -- stub = 0 */
  d = dif(x, 1);
  put 'DIF(10,1) = ' d;
  y = 25;
  e = dif(y, 2);
  put 'DIF(25,2) = ' e;
run;
