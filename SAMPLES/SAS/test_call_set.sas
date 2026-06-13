/* test_call_set.sas - CALL SET : liaison dataset (stub) */
data _null_;
  x = 0;
  call set(x);
  put 'CALL SET : stub OK';
run;
