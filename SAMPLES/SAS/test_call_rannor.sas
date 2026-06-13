/* test_call_rannor.sas - CALL RANNOR : loi normale (stub) */
data _null_;
  seed = 31415;
  result = 0;
  call rannor(seed, result);
  put 'CALL RANNOR result=' result;
run;
