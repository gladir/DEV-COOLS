/* test_lgamma.sas - LGAMMA : logarithme naturel de la fonction Gamma (stub) */
data _null_;
  a = lgamma(1);
  put 'LGAMMA(1) = ' a;
  b = lgamma(5);
  put 'LGAMMA(5) = ' b;
run;
