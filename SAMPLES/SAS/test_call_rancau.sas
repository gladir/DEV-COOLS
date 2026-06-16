/* test_call_rancau.sas - CALL RANCAU : loi de Cauchy */
data _null_;
  seed = 99;
  result = 0;
  call rancau(seed, result);
  put 'CALL RANCAU result=' result '  (attendu: 2)';
run;
