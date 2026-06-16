/* test_doptnum.sas - DOPTNUM : nombre d attributs de repertoire */
data _null_;
  did = 0;
  n = doptnum(did);
  put 'DOPTNUM(0) = ' n '  (attendu: 0)';
  ok = doptnum(7);
  put 'DOPTNUM(7) = ' ok '  (attendu: 1)';
run;
