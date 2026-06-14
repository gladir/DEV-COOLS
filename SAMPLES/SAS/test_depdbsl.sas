/* test_depdbsl.sas - DEPDBSL : depreciation degressif/lineaire (stub) */
data _null_;
  a = depdbsl(10000, 1000, 5, 3, 2);
  put 'DEPDBSL(10000,1000,5,3,2) = ' a;
run;
