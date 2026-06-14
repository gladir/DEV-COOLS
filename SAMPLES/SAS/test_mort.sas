/* test_mort.sas - MORT : parametres d amortissement (stub) */
data _null_;
  /* MORT(a, r, n, x) */
  m = mort(100000, 5, 360, 0);
  put 'MORT(100000,5,360,0) = ' m;
run;
