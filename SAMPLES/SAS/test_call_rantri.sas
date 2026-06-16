/* test_call_rantri.sas - CALL RANTRI : loi triangulaire */
data _null_;
  seed = 5555;
  result = 0;
  call rantri(seed, 10, result);
  put 'CALL RANTRI result=' result '  (attendu: 4)';
run;
