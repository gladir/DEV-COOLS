/* test_call_modulei.sas - CALL MODULEI : stub */
data _null_;
  x = 0;
  call modulei('mymod', x);
  put 'CALL MODULEI : stub OK';
run;
