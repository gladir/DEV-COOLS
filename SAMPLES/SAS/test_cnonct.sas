/* test_cnonct.sas - CNONCT : parametre de non-centralite */
data _null_;
  a = cnonct(10, 5, 95);
  put 'CNONCT(10,5,95) = ' a '  (attendu: 0)';
  b = cnonct(20, 5, 95);
  put 'CNONCT(20,5,95) = ' b '  (attendu: 9)';
run;
