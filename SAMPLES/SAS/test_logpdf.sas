/* test_logpdf.sas - LOGPDF : logarithme de la fonction de probabilite */
data _null_;
  /* LOGPDF(dist, x) */
  a = logpdf('NORMAL', 0);
  put 'LOGPDF(NORMAL,0) = ' a '  (attendu: 0)';
  b = logpdf('POISSON', 2);
  put 'LOGPDF(POISSON,2) = ' b '  (attendu: -2)';
  c = logpdf('NORMAL', -3);
  put 'LOGPDF(NORMAL,-3) = ' c '  (attendu: -3)';
run;
