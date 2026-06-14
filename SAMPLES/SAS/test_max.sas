/* test_max.sas - MAX : valeur la plus haute */
data _null_;
  a = max(3, 7);
  put 'MAX(3,7) = ' a;
  b = max(10, 5);
  put 'MAX(10,5) = ' b;
  c = max(0, 0);
  put 'MAX(0,0) = ' c;
run;
