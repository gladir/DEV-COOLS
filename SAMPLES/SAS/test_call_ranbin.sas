/* test_call_ranbin.sas - CALL RANBIN : loi binomiale */
data _null_;
  seed = 12345;
  result = 0;
  call ranbin(seed, 10, 0, result);
  put 'CALL RANBIN(0) result=' result '  (attendu: 0)';
  call ranbin(seed, 10, 50, result);
  put 'CALL RANBIN(50) result=' result '  (attendu: 4)';
run;
