/* test_betainv.sas - BETAINV : quantile distribution Beta (stub) */
data _null_;
  a = betainv(0, 2, 3);
  put 'BETAINV(0,2,3) = ' a;
  b = betainv(1, 2, 3);
  put 'BETAINV(1,2,3) = ' b;
run;
