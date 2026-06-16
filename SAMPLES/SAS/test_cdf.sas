/* test_cdf.sas - CDF : fonction de repartition */
data _null_;
  /* Backend entier : CDF normale approximee comme PROBNORM */
  p = cdf(0, 0);
  put 'CDF(0,0) = ' p '  (attendu: 0)';
  q = cdf(0, 1);
  put 'CDF(0,1) = ' q '  (attendu: 1)';
run;
