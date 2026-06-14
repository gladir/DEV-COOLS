/* test_lag.sas - LAG : valeur precedente d une variable (stub) */
data _null_;
  x = 10;
  prev = lag(x);
  put 'LAG(10) = ' prev;
  x = 20;
  prev2 = lag(x);
  put 'LAG(20) = ' prev2;
run;
