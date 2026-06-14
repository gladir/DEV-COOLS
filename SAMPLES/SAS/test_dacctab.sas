/* test_dacctab.sas - DACCTAB : depreciation par table (stub) */
data _null_;
  a = dacctab(10000, 1000, 5, 3);
  put 'DACCTAB(10000,1000,5,3) = ' a;
run;
