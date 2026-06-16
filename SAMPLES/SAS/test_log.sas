/* test_log.sas - LOG : logarithme naturel (base e) */
data _null_;
  a = log(1);
  put 'LOG(1) = ' a '  (attendu: 0)';
  b = log(10);
  put 'LOG(10) = ' b '  (attendu: 2)';
run;
