/* test_logsdf.sas - LOGSDF : logarithme de la fonction de survie (stub) */
data _null_;
  /* LOGSDF(dist, x) */
  a = logsdf('NORMAL', 0);
  put 'LOGSDF(NORMAL,0) = ' a;
run;
