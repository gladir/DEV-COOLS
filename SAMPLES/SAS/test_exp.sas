/* test_exp.sas - EXP : exponentielle e^x */
data _null_;
  a = exp(0);
  put 'EXP(0) = ' a '  (attendu: 1)';
  b = exp(1);
  put 'EXP(1) = ' b '  (attendu: 3)';
  c = exp(2);
  put 'EXP(2) = ' c '  (attendu: 7)';
run;
