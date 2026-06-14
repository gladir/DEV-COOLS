/* test_deptab.sas - DEPTAB : depreciation par table (stub) */
data _null_;
  a = deptab(10000, 1000, 5, 1);
  put 'DEPTAB(10000,1000,5,1) = ' a;
run;
