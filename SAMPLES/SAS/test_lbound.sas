/* test_lbound.sas - LBOUND : limite basse d un tableau (retourne 1) */
data _null_;
  array scores {5} s1 s2 s3 s4 s5;
  lo = lbound(scores);
  put 'LBOUND(scores{5}) = ' lo;
run;
