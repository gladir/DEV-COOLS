/* test_arsin.sas - ARSIN : arc sinus (stub) */
data _null_;
  a = arsin(0);
  put 'ARSIN(0) = ' a;
  b = arsin(1);
  put 'ARSIN(1) = ' b;
run;
