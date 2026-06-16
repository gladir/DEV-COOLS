/* test_atan.sas - ATAN : arc tangente */
data _null_;
  a = atan(0);
  put 'ATAN(0) = ' a;
  b = atan(1);
  put 'ATAN(1) = ' b;
run;
