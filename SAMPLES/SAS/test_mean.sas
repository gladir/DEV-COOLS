/* test_mean.sas - MEAN : moyenne arithmetique (stub) */
data _null_;
  a = mean(5);
  put 'MEAN(5) = ' a;
  b = mean(10);
  put 'MEAN(10) = ' b;
run;
