/* test_dim.sas - DIM : nombre d elements d un tableau */
data _null_;
  array scores {5} s1 s2 s3 s4 s5;
  n = dim(scores);
  put 'DIM(scores{5}) = ' n;
  array vals {3} v1 v2 v3;
  m = dim(vals);
  put 'DIM(vals{3}) = ' m;
  array big {10} b1-b10;
  k = dim(big);
  put 'DIM(big{10}) = ' k;
run;
