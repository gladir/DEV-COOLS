/* test_jbessel.sas - JBESSEL : valeur d une fonction Bessel (stub) */
data _null_;
  /* JBESSEL(nu, x) */
  a = jbessel(0, 1);
  put 'JBESSEL(0,1) = ' a;
  b = jbessel(1, 2);
  put 'JBESSEL(1,2) = ' b;
run;
