/* test_close.sas - CLOSE : statut de fermeture dataset */
data _null_;
  dsid = 0;
  rc = close(dsid);
  put 'CLOSE(0) = ' rc '  (attendu: -1)';
  ok = close(7);
  put 'CLOSE(7) = ' ok '  (attendu: 0)';
run;
