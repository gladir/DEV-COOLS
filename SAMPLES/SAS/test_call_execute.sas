/* test_call_execute.sas - CALL EXECUTE : stub */
data _null_;
  cmd = 'data test; x=1; run;';
  call execute(cmd);
  put 'CALL EXECUTE : stub OK';
run;
