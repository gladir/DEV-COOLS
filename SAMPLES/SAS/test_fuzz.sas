/* test_fuzz.sas - FUZZ : entier le plus proche si dans 1E-12 */
data _null_;
  a = fuzz(3);
  put 'FUZZ(3) = ' a;
  b = fuzz(7);
  put 'FUZZ(7) = ' b;
  c = fuzz(0);
  put 'FUZZ(0) = ' c;
run;
