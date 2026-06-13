/* test_call_vname.sas - CALL VNAME : nom de variable */
data _null_;
  x = 42;
  namvar = ' ';
  call vname(x, namvar);
  put 'VNAME(x) = ' namvar;
  y = 99;
  call vname(y, namvar);
  put 'VNAME(y) = ' namvar;
run;
