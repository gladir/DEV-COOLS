/* test_call_ranexp.sas - CALL RANEXP : loi exponentielle */
data _null_;
  seed = 777;
  result = 0;
  call ranexp(seed, result);
  put 'CALL RANEXP result=' result '  (attendu: 1)';
run;
