/* test_call_set.sas - CALL SET : affectation locale */
data _null_;
  x = 0;
  call set(x, 42);
  put 'CALL SET x=' x '  (attendu: 42)';
run;
