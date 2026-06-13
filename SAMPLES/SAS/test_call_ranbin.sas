/* test_call_ranbin.sas - CALL RANBIN : loi binomiale (stub) */
data _null_;
  seed = 12345;
  result = 0;
  call ranbin(seed, result);
  put 'CALL RANBIN result=' result;
  call ranbin(seed, result);
  put 'CALL RANBIN result=' result;
run;
