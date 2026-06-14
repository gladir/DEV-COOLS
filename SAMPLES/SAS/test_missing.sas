/* test_missing.sas - MISSING : detecter une valeur manquante (stub) */
data _null_;
  x = 5;
  r = missing(x);
  put 'MISSING(5) = ' r;
  y = 0;
  r2 = missing(y);
  put 'MISSING(0) = ' r2;
run;
