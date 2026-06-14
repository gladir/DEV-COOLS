/* test_logpdf.sas - LOGPDF : logarithme de la fonction de probabilite (stub) */
data _null_;
  /* LOGPDF(dist, x) */
  a = logpdf('NORMAL', 0);
  put 'LOGPDF(NORMAL,0) = ' a;
  b = logpdf('POISSON', 2);
  put 'LOGPDF(POISSON,2) = ' b;
run;
