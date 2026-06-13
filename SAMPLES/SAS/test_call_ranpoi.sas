/* test_call_ranpoi.sas - CALL RANPOI : loi de Poisson (stub) */
data _null_;
  seed = 1001;
  result = 0;
  call ranpoi(seed, result);
  put 'CALL RANPOI result=' result;
run;
