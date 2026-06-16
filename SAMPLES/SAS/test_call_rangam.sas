/* test_call_rangam.sas - CALL RANGAM : loi gamma */
data _null_;
  seed = 42;
  result = 0;
  call rangam(seed, 2, result);
  put 'CALL RANGAM result=' result '  (attendu: 1)';
run;
