/* test_normal.sas - NORMAL : nombre aleatoire distribution normale (stub) */
data _null_;
  r = normal(12345);
  put 'NORMAL(12345) = ' r;
  r2 = normal(0);
  put 'NORMAL(0) = ' r2;
run;
