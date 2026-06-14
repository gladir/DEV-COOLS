/* test_cv.sas - CV : coefficient de variation (stub) */
data _null_;
  /* CV de deux valeurs (stub=0) */
  a = cv(10, 20);
  put 'CV(10,20) = ' a;
  b = cv(5, 15);
  put 'CV(5,15) = ' b;
run;
