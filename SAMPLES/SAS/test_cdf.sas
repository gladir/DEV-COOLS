/* test_cdf.sas - CDF : fonction de repartition (stub) */
data _null_;
  /* CDF('NORMAL', 0) = 0.5 (stub retourne 0) */
  p = cdf(0, 0);
  put 'CDF(0,0) = ' p;
  /* CDF avec valeur positive */
  q = cdf(0, 1);
  put 'CDF(0,1) = ' q;
run;
