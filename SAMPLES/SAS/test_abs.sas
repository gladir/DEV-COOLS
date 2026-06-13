/* test_abs.sas - ABS : valeur absolue */
data _null_;
  a = abs(-42);
  put 'ABS(-42) = ' a;
  b = abs(7);
  put 'ABS(7) = ' b;
  c = abs(0);
  put 'ABS(0) = ' c;
run;
