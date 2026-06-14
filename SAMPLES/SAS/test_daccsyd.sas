/* test_daccsyd.sas - DACCSYD : depreciation somme annees (stub) */
data _null_;
  a = daccsyd(10000, 1000, 5, 3);
  put 'DACCSYD(10000,1000,5,3) = ' a;
run;
