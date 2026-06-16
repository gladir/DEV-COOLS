/* test_dnum.sas - DNUM : nombre de membres d un repertoire */
data _null_;
  did = 0;
  n = dnum(did);
  put 'DNUM(0) = ' n '  (attendu: 0)';
  ok = dnum(7);
  put 'DNUM(7) = ' ok '  (attendu: 1)';
run;
