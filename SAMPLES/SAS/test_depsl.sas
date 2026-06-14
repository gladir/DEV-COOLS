/* test_depsl.sas - DEPSL : depreciation lineaire (stub) */
data _null_;
  /* DEPSL(cout, val_residuelle, vie, periode) */
  a = depsl(10000, 1000, 5, 1);
  put 'DEPSL(10000,1000,5,1) = ' a;
  b = depsl(10000, 1000, 5, 3);
  put 'DEPSL(10000,1000,5,3) = ' b;
run;
