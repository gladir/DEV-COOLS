/* test_digamma.sas - DIGAMMA : fonction digamma (stub) */
data _null_;
  /* DIGAMMA(1) = -gamma_euler ~ -0.5772 (stub=0) */
  a = digamma(1);
  put 'DIGAMMA(1) = ' a;
  b = digamma(2);
  put 'DIGAMMA(2) = ' b;
run;
