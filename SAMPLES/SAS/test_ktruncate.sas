/* test_ktruncate.sas - KTRUNCATE : tronquer une valeur numerique (stub) */
data _null_;
  /* KTRUNCATE(x, len) */
  a = ktruncate(123456, 3);
  put 'KTRUNCATE(123456,3) = ' a;
run;
