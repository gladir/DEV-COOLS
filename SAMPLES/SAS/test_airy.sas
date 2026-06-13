/* test_airy.sas - AIRY : fonction d Airy (stub) */
data _null_;
  a = airy(0);
  put 'AIRY(0) = ' a;
  b = airy(1);
  put 'AIRY(1) = ' b;
run;
