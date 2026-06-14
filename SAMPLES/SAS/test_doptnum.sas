/* test_doptnum.sas - DOPTNUM : nombre d attributs de repertoire (stub) */
data _null_;
  did = 0;
  n = doptnum(did);
  put 'DOPTNUM(0) = ' n;
run;
