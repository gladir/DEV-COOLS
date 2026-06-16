/* test_call_module.sas - CALL MODULE */
data _null_;
  x = 0;
  call module('mymod', x);
  put 'CALL MODULE status=' x '  (attendu: 5)';
run;
