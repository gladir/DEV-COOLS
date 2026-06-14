/* test_depsyd.sas - DEPSYD : depreciation somme annees (stub) */
data _null_;
  a = depsyd(10000, 1000, 5, 1);
  put 'DEPSYD(10000,1000,5,1) = ' a;
  b = depsyd(10000, 1000, 5, 5);
  put 'DEPSYD(10000,1000,5,5) = ' b;
run;
