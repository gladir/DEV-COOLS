/* test_call_rancau.sas - CALL RANCAU : loi de Cauchy (stub) */
data _null_;
  seed = 99;
  result = 0;
  call rancau(seed, result);
  put 'CALL RANCAU result=' result;
run;
