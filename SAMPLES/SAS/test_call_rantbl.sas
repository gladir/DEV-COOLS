/* test_call_rantbl.sas - CALL RANTBL : distribution tabulee */
data _null_;
  seed = 2023;
  result = 0;
  call rantbl(seed, 0, 1, result);
  put 'CALL RANTBL result=' result '  (attendu: 2)';
run;
