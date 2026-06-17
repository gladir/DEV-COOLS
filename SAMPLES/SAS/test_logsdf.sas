/* test_logsdf.sas - LOGSDF : logarithme de la fonction de survie */
data _null_;
  /* LOGSDF(dist, x) */
  a = logsdf('NORMAL', 0);
  put 'LOGSDF(NORMAL,0) = ' a '  (attendu: 0)';
  b = logsdf('NORMAL', 3);
  put 'LOGSDF(NORMAL,3) = ' b '  (attendu: -3)';
  c = logsdf('NORMAL', -2);
  put 'LOGSDF(NORMAL,-2) = ' c '  (attendu: 0)';
run;
