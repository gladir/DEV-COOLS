/* test_ibessel.sas - IBESSEL : fonction Bessel modifiée (stub) */
data _null_;
  /* IBESSEL(nu, x, kode) */
  a = ibessel(0, 1, 1);
  put 'IBESSEL(0,1,1) = ' a;
  b = ibessel(1, 2, 0);
  put 'IBESSEL(1,2,0) = ' b;
run;
