/* test_call_rantri.sas - CALL RANTRI : loi triangulaire (stub) */
data _null_;
  seed = 5555;
  result = 0;
  call rantri(seed, result);
  put 'CALL RANTRI result=' result;
run;
