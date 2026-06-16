/* test_call_modulei.sas - CALL MODULEI */
data _null_;
  x = 0;
  call modulei('mymod', x);
  put 'CALL MODULEI status=' x '  (attendu: 5)';
run;
