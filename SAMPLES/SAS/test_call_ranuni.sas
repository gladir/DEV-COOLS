/* test_call_ranuni.sas - CALL RANUNI : loi uniforme (stub) */
data _null_;
  seed = 9999;
  result = 0;
  call ranuni(seed, result);
  put 'CALL RANUNI result=' result;
  call ranuni(seed, result);
  put 'CALL RANUNI result=' result;
run;
