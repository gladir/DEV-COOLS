/* test_call_module.sas - CALL MODULE : stub */
data _null_;
  x = 0;
  call module('mymod', x);
  put 'CALL MODULE : stub OK';
run;
