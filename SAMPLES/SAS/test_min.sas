/* test_min.sas - MIN : valeur la plus basse */
data _null_;
  a = min(3, 7);
  put 'MIN(3,7) = ' a;
  b = min(10, 5);
  put 'MIN(10,5) = ' b;
  c = min(0, 0);
  put 'MIN(0,0) = ' c;
run;
