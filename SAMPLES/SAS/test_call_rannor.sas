/* test_call_rannor.sas - CALL RANNOR : loi normale */
data _null_;
  seed = 31415;
  result = 0;
  call rannor(seed, result);
  put 'CALL RANNOR result=' result '  (attendu: -2)';
run;
