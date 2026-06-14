/* test_daccdbsl.sas - DACCDBSL : depreciation degressif/linaire (stub) */
data _null_;
  a = daccdbsl(10000, 1000, 5, 3, 2);
  put 'DACCDBSL(10000,1000,5,3,2) = ' a;
run;
