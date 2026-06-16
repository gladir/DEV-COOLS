/* test_call_ranpoi.sas - CALL RANPOI : loi de Poisson */
data _null_;
  seed = 1001;
  result = 0;
  call ranpoi(seed, 3, result);
  put 'CALL RANPOI result=' result '  (attendu: 1)';
run;
