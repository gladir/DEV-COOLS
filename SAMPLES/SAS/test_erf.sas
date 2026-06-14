/* test_erf.sas - ERF : fonction erreur (stub) */
data _null_;
  a = erf(0);
  put 'ERF(0) = ' a;
  b = erf(1);
  put 'ERF(1) = ' b;
run;
