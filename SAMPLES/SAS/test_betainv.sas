/* test_betainv.sas - BETAINV : quantile distribution Beta */
data _null_;
  a = betainv(0, 2, 3);
  put 'BETAINV(0,2,3) = ' a '  (attendu: 0)';
  b = betainv(1, 2, 3);
  put 'BETAINV(1,2,3) = ' b '  (attendu: 1)';
run;
