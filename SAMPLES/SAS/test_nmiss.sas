/* test_nmiss.sas - NMISS : nombre d arguments absents (stub) */
data _null_;
  cnt = nmiss(1);
  put 'NMISS(1) = ' cnt;
  cnt2 = nmiss(0);
  put 'NMISS(0) = ' cnt2;
run;
