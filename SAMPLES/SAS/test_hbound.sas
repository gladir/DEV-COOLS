/* test_hbound.sas - HBOUND : limite haute d un tableau (stub) */
data _null_;
  array scores {5} s1 s2 s3 s4 s5;
  h = hbound(scores);
  put 'HBOUND(scores{5}) = ' h;
run;
