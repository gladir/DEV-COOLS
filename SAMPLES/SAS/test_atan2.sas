/* test_atan2.sas - ATAN2 : arc tangente quadrant */
data _null_;
  a = atan2(1, 1);
  put 'ATAN2(1,1) = ' a;
  b = atan2(0, 1);
  put 'ATAN2(0,1) = ' b;
run;
