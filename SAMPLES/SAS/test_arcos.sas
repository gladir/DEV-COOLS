/* test_arcos.sas - ARCOS : arc cosinus (stub) */
data _null_;
  a = arcos(1);
  put 'ARCOS(1) = ' a;
  b = arcos(0);
  put 'ARCOS(0) = ' b;
run;
