/* test_dclose.sas - DCLOSE : fermer un repertoire */
data _null_;
  did = 0;
  rc = dclose(did);
  put 'DCLOSE(0) = ' rc '  (attendu: -1)';
  ok = dclose(7);
  put 'DCLOSE(7) = ' ok '  (attendu: 0)';
run;
