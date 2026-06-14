/* test_datdif.sas - DATDIF : jours entre deux dates (stub) */
data _null_;
  /* DATDIF(d1, d2, base) = jours entre d1 et d2 (stub=0) */
  d1 = 0;
  d2 = 365;
  a = datdif(d1, d2, 1);
  put 'DATDIF(0,365,1) = ' a;
run;
