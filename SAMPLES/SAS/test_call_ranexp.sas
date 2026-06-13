/* test_call_ranexp.sas - CALL RANEXP : loi exponentielle (stub) */
data _null_;
  seed = 777;
  result = 0;
  call ranexp(seed, result);
  put 'CALL RANEXP result=' result;
run;
