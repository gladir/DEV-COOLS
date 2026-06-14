/* test_gamma.sas - GAMMA : valeur de la fonction Gamma (stub) */
data _null_;
  a = gamma(1);
  put 'GAMMA(1) = ' a;
  b = gamma(5);
  put 'GAMMA(5) = ' b;
run;
