/* test_call_rantbl.sas - CALL RANTBL : distribution tabulee (stub) */
data _null_;
  seed = 2023;
  result = 0;
  call rantbl(seed, result);
  put 'CALL RANTBL result=' result;
run;
