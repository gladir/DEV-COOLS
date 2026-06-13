/* test_call_rangam.sas - CALL RANGAM : loi gamma (stub) */
data _null_;
  seed = 42;
  result = 0;
  call rangam(seed, result);
  put 'CALL RANGAM result=' result;
run;
