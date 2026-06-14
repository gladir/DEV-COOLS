/* test_n.sas - N : nombre d arguments non-absents (stub) */
data _null_;
  cnt = n(1);
  put 'N(1) = ' cnt;
  cnt2 = n(5);
  put 'N(5) = ' cnt2;
run;
