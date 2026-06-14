/* test_fact.sas - FACT : factorielle n! */
data _null_;
  a = fact(0);
  put 'FACT(0) = ' a;
  b = fact(1);
  put 'FACT(1) = ' b;
  c = fact(5);
  put 'FACT(5) = ' c;
  d = fact(10);
  put 'FACT(10) = ' d;
run;
