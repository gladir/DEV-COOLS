/* test_exp.sas - EXP : exponentielle e^x */
data _null_;
  a = exp(0);
  put 'EXP(0) = ' a;
  b = exp(1);
  put 'EXP(1) = ' b;
  c = exp(2);
  put 'EXP(2) = ' c;
run;
