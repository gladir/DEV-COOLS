/* test_call_label.sas - CALL LABEL : stub */
data _null_;
  x = 42;
  lbl = 'Valeur de X';
  call label(x, lbl);
  put 'CALL LABEL : stub OK';
run;
