/* test_daccsl.sas - DACCSL : depreciation lineaire cumul (stub) */
data _null_;
  /* DACCSL(cout, valresid, vie, periode) */
  a = daccsl(10000, 1000, 5, 3);
  put 'DACCSL(10000,1000,5,3) = ' a;
  b = daccsl(20000, 2000, 10, 5);
  put 'DACCSL(20000,2000,10,5) = ' b;
run;
