/* test_log.sas - LOG : logarithme naturel (base e) */
data _null_;
  a = log(1);
  put 'LOG(1) = ' a;
  b = log(10);
  put 'LOG(10) = ' b;
run;
